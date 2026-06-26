#' Add WoRMS taxonomy to predator and prey
#'
#' Left-joins scientific names and higher taxonomy (class, order, family,
#' phylum) for both predators and prey using the bundled WoRMS lookup table
#' ([worms_lookup], built in `data-raw/build_worms_lookup.R`).
#' Prey with `aphia_id_prey = NA` in non-empty stomachs are labelled
#' `"Unknown"` so their weight is not silently lost downstream.
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

  dat <- dat |>
    dplyr::mutate(
      prey_scientific_name = dplyr::if_else(
        is.na(aphia_id_prey) & stomach_status != "empty",
        "Unknown",
        prey_scientific_name
      )
    )

  n_pred_unresolved <- dplyr::n_distinct(
    dat$aphia_id_predator[is.na(dat$predator_scientific_name) & !is.na(dat$aphia_id_predator)]
  )
  n_prey_unresolved <- dplyr::n_distinct(
    dat$aphia_id_prey[is.na(dat$prey_scientific_name) & !is.na(dat$aphia_id_prey)]
  )

  pred_bullet <- if (n_pred_unresolved == 0) "v" else "!"
  prey_bullet <- if (n_prey_unresolved == 0) "v" else "!"

  cli::cli_inform(c(
    "add_taxonomy(): WoRMS names resolved",
    stats::setNames(
      c(
        "Predator AphiaIDs: {n_pred_ids} unique, {n_pred_unresolved} unresolved",
        "Prey AphiaIDs: {n_prey_ids} unique, {n_prey_unresolved} unresolved"
      ),
      c(pred_bullet, prey_bullet)
    )
  ))

  dat
}
