#' Flag implausible records
#'
#' Adds a `sense_flag` column (pipe-separated string of active checks) to mark
#' rows that fail any of the following checks:
#'
#' - `prey_length`: prey longer than predator
#' - `prey_weight`: individual prey heavier than predator
#' - `stomach_weight`: total stomach content weight exceeds predator weight
#' - `pred_length`: predator length <= 0 or >= 999 (sentinel value)
#' - `count_censored`: count was the 9999 sentinel (unknown multiplicity)
#' - `coord_outlier`: lat/lon outside plausible bounds covering the North Sea, Baltic, and Celtic Sea region (lat 45–72, lon -20–30)
#'
#' @param dat Tibble from [trim_data()].
#'
#' @return `dat` with an added `sense_flag` column (`NA` = no flag).
#' @export
sense_check <- function(dat) {
  n_total <- nrow(dat)

  stomach_over <- dat |>
    dplyr::filter(stomach_status == "food", !is.na(predator_weight)) |>
    dplyr::summarise(
      stomach_total = sum(prey_weight_all_ind, na.rm = TRUE),
      predator_weight = dplyr::first(predator_weight),
      .by = tbl_predator_information_id
    ) |>
    dplyr::filter(stomach_total > predator_weight) |>
    dplyr::pull(tbl_predator_information_id)

  dat <- dat |>
    dplyr::mutate(
      .f_prey_length = !is.na(prey_length) & !is.na(pred_length) & prey_length > pred_length,
      .f_prey_weight = !is.na(prey_weight_ind) & !is.na(predator_weight) & prey_weight_ind > predator_weight,
      .f_stomach_wgt = tbl_predator_information_id %in% stomach_over,
      .f_pred_length = !is.na(pred_length) & (pred_length <= 0 | pred_length >= 999),
      .f_count_cens  = count_censored,
      .f_coord       = !is.na(lat) & !is.na(lon) &
                         (lat < 45 | lat > 72 | lon < -20 | lon > 30),
      sense_flag = dplyr::case_when(
        .f_prey_length & .f_prey_weight & .f_stomach_wgt & .f_pred_length ~ "prey_length|prey_weight|stomach_weight|pred_length",
        .f_prey_length & .f_prey_weight & .f_stomach_wgt ~ "prey_length|prey_weight|stomach_weight",
        .f_prey_length & .f_prey_weight & .f_pred_length ~ "prey_length|prey_weight|pred_length",
        .f_prey_length & .f_stomach_wgt & .f_pred_length ~ "prey_length|stomach_weight|pred_length",
        .f_prey_weight & .f_stomach_wgt & .f_pred_length ~ "prey_weight|stomach_weight|pred_length",
        .f_prey_length & .f_prey_weight ~ "prey_length|prey_weight",
        .f_prey_length & .f_stomach_wgt ~ "prey_length|stomach_weight",
        .f_prey_length & .f_pred_length ~ "prey_length|pred_length",
        .f_prey_weight & .f_stomach_wgt ~ "prey_weight|stomach_weight",
        .f_prey_weight & .f_pred_length ~ "prey_weight|pred_length",
        .f_stomach_wgt & .f_pred_length ~ "stomach_weight|pred_length",
        .f_prey_length ~ "prey_length",
        .f_prey_weight ~ "prey_weight",
        .f_stomach_wgt ~ "stomach_weight",
        .f_pred_length ~ "pred_length",
        .f_count_cens  ~ "count_censored",
        .f_coord       ~ "coord_outlier",
        TRUE ~ NA_character_
      )
    ) |>
    dplyr::select(-.f_prey_length, -.f_prey_weight, -.f_stomach_wgt, -.f_pred_length, -.f_count_cens, -.f_coord)

  report_check <- function(flag_key, label) {
    rows <- dplyr::filter(dat, grepl(flag_key, sense_flag, fixed = TRUE))
    n_row <- nrow(rows)
    if (n_row == 0L) {
      return(invisible(NULL))
    }
    pct <- sprintf("%.1f%%", 100 * n_row / n_total)
    preds <- unique(rows$tbl_predator_information_id)
    id_str <- paste(head(preds, 5L), collapse = ", ")
    if (length(preds) > 5L) id_str <- paste0(id_str, ", ...")
    cli::cli_inform(c(
      "!" = "{label}: {n_row} row{?s} ({pct}) across {length(preds)} predator{?s}",
      " " = "tbl_predator_information_id: {id_str}"
    ))
  }

  n_flagged <- sum(!is.na(dat$sense_flag))
  pct <- sprintf("%.2f%%", 100 * n_flagged / n_total)

  cli::cli_inform("sense_check(): {n_total} rows")
  report_check("prey_length", "prey longer than predator (same unit assumed)")
  report_check("prey_weight", "individual prey heavier than predator")
  report_check("stomach_weight", "total stomach content heavier than predator")
  report_check("pred_length", "predator length implausible (<=0 or >=999, likely sentinel value)")
  report_check("count_censored", "count was 9999 sentinel (unknown multiplicity)")
  report_check("coord_outlier", "coordinates outside region (lat 45-72, lon -20 to 30)")
  cli::cli_inform(c(
    "i" = "{n_flagged} row{?s} flagged ({pct})",
    "i" = "Use {.fn drop_flagged} to remove, or inspect {.field tbl_predator_information_id} in raw data"
  ))

  dat
}

#' Remove flagged records
#'
#' Removes all rows where `sense_flag` is not `NA` (i.e., rows flagged by
#' [sense_check()]).
#'
#' @param dat Tibble from [sense_check()].
#'
#' @return `dat` with flagged rows removed.
#' @export
drop_flagged <- function(dat) {
  n_before <- nrow(dat)
  dat <- dplyr::filter(dat, is.na(sense_flag))
  n_dropped <- n_before - nrow(dat)
  pct <- sprintf("%.2f%%", 100 * n_dropped / n_before)
  cli::cli_inform(c("v" = "drop_flagged(): removed {n_dropped} row{?s} ({pct}), {nrow(dat)} remaining"))
  dat
}
