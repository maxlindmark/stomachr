#' Read and join the four ICES stomach content CSVs
#'
#' Reads `File_information.csv`, `HaulInformation.csv`,
#' `PredatorInformation.csv`, and `PreyInformation.csv` from `path`, joins
#' them into a single flat tibble, classifies each stomach as `"food"`,
#' `"empty"`, or `"unidentified"`, deduplicates exact-duplicate prey rows,
#' and optionally imputes missing coordinates from ICES rectangle midpoints.
#'
#' @param path Path to the directory containing the four ICES CSV files.
#' @param impute_coords If `TRUE` (default), missing `lat`/`lon` are imputed
#'   from the ICES rectangle midpoint via [mapplots::ices.rect()].
#'
#' @return A tibble with one row per prey record per predator. Empty and
#'   unidentified stomachs contribute one `NA` prey row each.
#' @export
join_stomach_data <- function(path, impute_coords = TRUE) {
  fi <- readr::read_csv(file.path(path, "File_information.csv"), show_col_types = FALSE) |>
    janitor::clean_names()
  hi <- readr::read_csv(
    file.path(path, "HaulInformation.csv"),
    col_types = readr::cols(ICESrectangle = readr::col_character()),
    show_col_types = FALSE
  ) |>
    janitor::clean_names() |>
    dplyr::rename(ices_rectangle = ice_srectangle)
  pred <- readr::read_csv(file.path(path, "PredatorInformation.csv"), show_col_types = FALSE) |>
    janitor::clean_names()
  prey <- readr::read_csv(file.path(path, "PreyInformation.csv"), show_col_types = FALSE) |>
    janitor::clean_names()

  hifi <- dplyr::left_join(hi, fi, by = "tbl_upload_id")

  pred <- dplyr::left_join(
    pred,
    hifi |> dplyr::select(
      tbl_upload_id, tbl_haul_id, country,
      shoot_lat, shoot_long, ices_rectangle, depth, survey
    ),
    by = c("tbl_upload_id", "tbl_haul_id")
  ) |>
    dplyr::rename(pred_length = length)

  # Classify stomach status before the prey join so the distinction between
  # truly empty stomachs and unidentified-only stomachs is not lost.
  prey_status <- prey |>
    dplyr::summarise(
      n_prey_rows = dplyr::n(),
      n_unidentified = sum(is.na(aphia_id_prey)),
      .by = tbl_predator_information_id
    ) |>
    dplyr::mutate(
      stomach_status = dplyr::case_when(
        n_unidentified == n_prey_rows ~ "unidentified",
        TRUE ~ "food"
      )
    ) |>
    dplyr::select(tbl_predator_information_id, stomach_status)

  pred <- pred |>
    dplyr::left_join(prey_status, by = "tbl_predator_information_id") |>
    dplyr::mutate(
      stomach_status = dplyr::if_else(is.na(stomach_status), "empty", stomach_status)
    )

  prey <- prey |>
    dplyr::left_join(fi |> dplyr::select(tbl_upload_id, country), by = "tbl_upload_id") |>
    dplyr::select(
      tbl_predator_information_id, tbl_prey_information_id,
      aphia_id_prey, ident_met, digestion_stage, grav_method,
      sub_factor, prey_sequence, count, unit_wgt, weight,
      unit_lngt, length, other_items, other_count, other_wgt, analysing_org,
      country
    ) |>
    dplyr::rename(prey_length = length)

  # Most records don't tag UnitWgt/UnitLngt. Where missing, fall back to
  # whatever unit that country's own labeled records use, rather than
  # assuming g/mm for everyone -- every country is 100% consistent in the
  # unit it uses when it does label (NO always mg/cm, everyone else always
  # g/mm when labeled).
  wgt_default <- prey |>
    dplyr::filter(!is.na(unit_wgt)) |>
    dplyr::count(country, unit_wgt, sort = TRUE) |>
    dplyr::distinct(country, .keep_all = TRUE) |>
    dplyr::select(country, wgt_default = unit_wgt)

  lngt_default <- prey |>
    dplyr::filter(!is.na(unit_lngt)) |>
    dplyr::count(country, unit_lngt, sort = TRUE) |>
    dplyr::distinct(country, .keep_all = TRUE) |>
    dplyr::select(country, lngt_default = unit_lngt)

  prey <- prey |>
    dplyr::left_join(wgt_default, by = "country") |>
    dplyr::left_join(lngt_default, by = "country") |>
    dplyr::mutate(
      unit_wgt  = dplyr::coalesce(unit_wgt, wgt_default, "g"),
      unit_lngt = dplyr::coalesce(unit_lngt, lngt_default, "mm")
    )

  unknown_wgt  <- setdiff(unique(prey$unit_wgt), c("g", "mg"))
  unknown_lngt <- setdiff(unique(prey$unit_lngt), c("mm", "cm"))
  if (length(unknown_wgt) || length(unknown_lngt)) {
    cli::cli_abort(c(
      "Unrecognised prey unit{?s} in raw data.",
      "i" = "unit_wgt: {.val {unknown_wgt}}",
      "i" = "unit_lngt: {.val {unknown_lngt}}"
    ))
  }

  prey <- prey |>
    dplyr::mutate(
      weight      = dplyr::if_else(unit_wgt == "mg", weight / 1000, weight),
      prey_length = dplyr::if_else(unit_lngt == "mm", prey_length / 10, prey_length)
    ) |>
    dplyr::select(-wgt_default, -lngt_default, -country) |>
    # Some submissions (e.g. NL) contain exact triplicate prey rows with
    # consecutive tbl_prey_information_id values; deduplicate before deriving.
    dplyr::distinct(
      tbl_predator_information_id, aphia_id_prey,
      count, weight, prey_length, digestion_stage,
      .keep_all = TRUE
    ) |>
    dplyr::mutate(
      # 9999 is the ICES sentinel for "count not recorded"; unknown multiplicity
      # makes weight-per-individual undefined, so flag before nulling.
      count_censored = !is.na(count) & count == 9999L,
      count = dplyr::case_when(
        count == 9999L ~ NA_integer_,
        is.na(count) ~ 1L,
        TRUE ~ count
      ),
      prey_weight_ind = weight / count
    )

  dat <- dplyr::left_join(pred, prey, by = "tbl_predator_information_id")

  if (impute_coords) {
    # Some submissions carry ICES rectangle codes mangled by spreadsheet
    # auto-formatting (e.g. "46E9" read as scientific notation and stored as
    # "46000000000"). Treat anything not matching the real format as if it
    # were missing, and recompute it from coordinates like any other gap.
    valid_rect <- "^[0-9]{2}[A-Za-z][0-9]$"
    has_valid_rect <- !is.na(dat$ices_rectangle) & grepl(valid_rect, dat$ices_rectangle)

    n_imputed_coords <- sum(is.na(dat$shoot_lat) & has_valid_rect)
    n_invalid_rect <- sum(!is.na(dat$ices_rectangle) & !has_valid_rect)

    rect_lookup <- dat |>
      dplyr::filter(is.na(shoot_lat), has_valid_rect) |>
      dplyr::distinct(ices_rectangle) |>
      dplyr::mutate(
        coords         = purrr::map(ices_rectangle, mapplots::ices.rect),
        shoot_lat_imp  = purrr::map_dbl(coords, "lat"),
        shoot_long_imp = purrr::map_dbl(coords, "lon")
      ) |>
      dplyr::select(ices_rectangle, shoot_lat_imp, shoot_long_imp)

    dat <- dat |>
      dplyr::left_join(rect_lookup, by = "ices_rectangle") |>
      dplyr::mutate(
        shoot_lat  = dplyr::coalesce(shoot_lat, shoot_lat_imp),
        shoot_long = dplyr::coalesce(shoot_long, shoot_long_imp)
      ) |>
      dplyr::select(-shoot_lat_imp, -shoot_long_imp) |>
      dplyr::mutate(
        ices_rectangle = dplyr::if_else(
          (is.na(ices_rectangle) | !grepl(valid_rect, ices_rectangle)) &
            !is.na(shoot_lat) & !is.na(shoot_long),
          mapplots::ices.rect2(shoot_long, shoot_lat),
          ices_rectangle
        )
      )
  }

  n_pred <- dplyr::n_distinct(dat$tbl_predator_information_id)
  n_tab <- pred |> dplyr::count(stomach_status)
  n_for_status <- function(status) {
    v <- n_tab$n[n_tab$stomach_status == status]
    if (length(v) == 0) 0L else v
  }
  n_empty <- n_for_status("empty")
  n_unid <- n_for_status("unidentified")
  n_food <- n_for_status("food")
  pct_food  <- sprintf("%.1f%%", 100 * n_food / n_pred)
  pct_empty <- sprintf("%.1f%%", 100 * n_empty / n_pred)
  pct_unid  <- sprintf("%.1f%%", 100 * n_unid / n_pred)

  coords_line <- if (impute_coords) {
    c("i" = "{fmt_n(n_imputed_coords)} {cli::qty(n_imputed_coords)}haul location{?s} imputed from ICES rectangle midpoint")
  }
  invalid_rect_line <- if (impute_coords && n_invalid_rect > 0) {
    c("!" = "{fmt_n(n_invalid_rect)} malformed ICES rectangle {cli::qty(n_invalid_rect)}code{?s} recomputed from coordinates")
  }

  cli::cli_inform(c(
    "{cli::col_cyan('join_stomach_data()')}: {fmt_n(n_pred)} {cli::qty(n_pred)}predator individual{?s}",
    "v" = "{fmt_n(n_food)} ({pct_food}) with identifiable prey",
    "i" = "{fmt_n(n_empty)} ({pct_empty}) empty or regurgitated",
    "i" = "{fmt_n(n_unid)} ({pct_unid}) with prey records but no prey species ID",
    " " = "(cannot contribute to diet composition but can contribute to total prey weight)",
    coords_line,
    invalid_rect_line,
    " " = ""
  ))

  dat |> dplyr::rename(lat = shoot_lat, lon = shoot_long)
}
