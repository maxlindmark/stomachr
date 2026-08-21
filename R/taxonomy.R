#' Add WoRMS taxonomy to predator and prey
#'
#' Left-joins scientific names and higher taxonomy (class, order, family,
#' phylum) for both predators and prey using the bundled WoRMS lookup table
#' ([worms_lookup], built in `data-raw/build_worms_lookup.R`).
#' Prey with no resolved scientific name in non-empty stomachs -- either
#' `aphia_id_prey = NA` (no id recorded), or an id that isn't in
#' [worms_lookup] -- are labelled `"Unknown"` so their weight is not
#' silently lost downstream.
#'
#' @param dat Tibble from [drop_invalid()].
#'
#' @return `dat` with added columns `predator_scientific_name`,
#'   `predator_class`, `predator_order`, `predator_family`,
#'   `predator_phylum`, and matching `prey_*` columns.
#' @export
add_taxonomy <- function(dat) {
  n_pred_ids <- dplyr::n_distinct(stats::na.omit(dat$aphia_id_predator))
  n_prey_ids <- dplyr::n_distinct(stats::na.omit(dat$aphia_id_prey))

  dat <- dat |>
    dplyr::left_join(
      worms_lookup |>
        dplyr::rename_with(\(x) paste0("predator_", x), -aphia_id),
      by = c("aphia_id_predator" = "aphia_id")
    )

  dat <- dat |>
    dplyr::left_join(
      worms_lookup |>
        dplyr::rename_with(\(x) paste0("prey_", x), -aphia_id),
      by = c("aphia_id_prey" = "aphia_id")
    )

  n_pred_unresolved <- dplyr::n_distinct(
    dat$aphia_id_predator[is.na(dat$predator_scientific_name) & !is.na(dat$aphia_id_predator)]
  )
  # captured before the "Unknown" fallback below overwrites prey_scientific_name
  # -- otherwise this would always read 0 once the fallback covers this case too
  n_prey_unresolved <- dplyr::n_distinct(
    dat$aphia_id_prey[is.na(dat$prey_scientific_name) & !is.na(dat$aphia_id_prey)]
  )

  dat <- dat |>
    dplyr::mutate(
      # covers both "no id was ever recorded" AND "an id was recorded but
      # isn't in worms_lookup" -- both leave prey_scientific_name NA
      # otherwise, and both carry the same silent-data-loss risk this
      # fallback exists to prevent
      prey_scientific_name = dplyr::if_else(
        is.na(prey_scientific_name) & stomach_status != "empty",
        "Unknown",
        prey_scientific_name
      )
    )

  pred_bullet <- if (n_pred_unresolved == 0) "v" else "!"
  prey_bullet <- if (n_prey_unresolved == 0) "v" else "!"

  # unresolved ids are often just missing from the cached lookup rather than
  # invalid -- worms_lookup is a snapshot, and new ids can appear in the live
  # ICES database after it was last built
  refresh_hint <- if (n_pred_unresolved > 0 || n_prey_unresolved > 0) {
    c("i" = "The bundled WoRMS lookup may be out of date.")
  }

  cli::cli_inform(c(
    "{cli::col_cyan('add_taxonomy()')}: WoRMS names resolved",
    stats::setNames(
      c(
        "Predator AphiaIDs: {fmt_n(n_pred_ids)} unique, {fmt_n(n_pred_unresolved)} unresolved",
        "Prey AphiaIDs: {fmt_n(n_prey_ids)} unique, {fmt_n(n_prey_unresolved)} unresolved"
      ),
      c(pred_bullet, prey_bullet)
    ),
    refresh_hint,
    " " = ""
  ))

  dat
}
