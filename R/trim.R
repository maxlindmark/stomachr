#' Trim to analysis-ready columns
#'
#' Drops the internal processing columns that are no longer needed after the
#' cleaning pipeline, keeping only the columns listed below.
#'
#' @param dat Tibble from [impute_size()].
#'
#' @return A tibble with columns: `tbl_upload_id`, `tbl_haul_id`,
#'   `tbl_predator_information_id`, `country`, `survey`, `year`, `month`,
#'   `day`, `time`, `lat`, `lon`, `ices_rectangle`, `depth`,
#'   `stomach_status`, `regurgitated`, `aphia_id_predator`,
#'   `predator_scientific_name`, `predator_class`, `predator_order`,
#'   `predator_family`, `pred_length`, `predator_weight`,
#'   `predator_weight_estimated`, `age`, `sex`, `tbl_prey_information_id`,
#'   `aphia_id_prey`, `prey_scientific_name`, `prey_class`, `prey_order`,
#'   `prey_family`, `digestion_stage`, `sub_factor`, `count`,
#'   `count_censored`, `prey_length`, `prey_weight_ind`,
#'   `prey_weight_all_ind`, `other_wgt`, `prey_lw_source`, `lw_source`,
#'   `pred_lw_source`, `analysing_org`.
#' @export
trim_data <- function(dat) {
  keep <- c(
    "tbl_upload_id", "tbl_haul_id", "tbl_predator_information_id",
    "country", "survey", "year", "month", "day", "time", "lat", "lon",
    "ices_rectangle", "depth", "stomach_status", "regurgitated",
    "aphia_id_predator", "predator_scientific_name", "predator_class",
    "predator_order", "predator_family", "pred_length",
    "predator_weight", "predator_weight_estimated", "age", "sex",
    "tbl_prey_information_id", "aphia_id_prey", "prey_scientific_name",
    "prey_class", "prey_order", "prey_family", "digestion_stage",
    "sub_factor", "count", "count_censored", "prey_length",
    "prey_weight_ind", "prey_weight_all_ind", "other_wgt",
    "prey_lw_source", "lw_source", "pred_lw_source", "analysing_org"
  )

  dropped <- setdiff(names(dat), keep)
  if (length(dropped) > 0) {
    cli::cli_inform(c(
      "trim_data(): dropped {length(dropped)} column{?s}:",
      " " = paste(dropped, collapse = ", ")
    ))
  }

  dat |> dplyr::select(dplyr::all_of(keep))
}
