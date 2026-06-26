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
  hi <- readr::read_csv(file.path(path, "HaulInformation.csv"), show_col_types = FALSE) |>
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
    dplyr::select(
      tbl_predator_information_id, tbl_prey_information_id,
      aphia_id_prey, ident_met, digestion_stage, grav_method,
      sub_factor, prey_sequence, count, unit_wgt, weight,
      unit_lngt, length, other_items, other_count, other_wgt, analysing_org
    ) |>
    dplyr::rename(prey_length = length) |>
    dplyr::mutate(prey_length = prey_length / 10) |> # mm -> cm
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
    n_imputed_coords <- sum(is.na(dat$shoot_lat) & !is.na(dat$ices_rectangle))

    rect_lookup <- dat |>
      dplyr::filter(is.na(shoot_lat), !is.na(ices_rectangle)) |>
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
          is.na(ices_rectangle) & !is.na(shoot_lat) & !is.na(shoot_long),
          mapplots::ices.rect2(shoot_long, shoot_lat),
          ices_rectangle
        )
      )
  }

  n_pred <- dplyr::n_distinct(dat$tbl_predator_information_id)
  n_tab <- pred |> dplyr::count(stomach_status)
  n_empty <- n_tab$n[n_tab$stomach_status == "empty"]
  n_unid <- n_tab$n[n_tab$stomach_status == "unidentified"]
  n_food <- n_tab$n[n_tab$stomach_status == "food"]

  coords_line <- if (impute_coords) {
    c("i" = "{n_imputed_coords} haul location{?s} imputed from ICES rectangle midpoint")
  }

  cli::cli_inform(c(
    "join_stomach_data(): {n_pred} predator individual{?s}",
    "v" = "{n_food} with identifiable prey",
    "i" = "{n_empty} empty or regurgitated",
    "i" = "{n_unid} with prey records but no prey species ID",
    " " = "(cannot contribute to diet composition but can contribute to total prey weight)",
    coords_line
  ))

  dat |> dplyr::rename(lat = shoot_lat, lon = shoot_long)
}
