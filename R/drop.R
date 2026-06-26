#' Drop invalid (regurgitated) predator records
#'
#' Removes predators where `regurgitated >= 1`. Stomach contents of regurgitated
#' fish are scientifically unusable for diet analysis.
#'
#' @param dat Tibble from [join_stomach_data()].
#' @param na_regurgitated `"keep"` (default) treats `NA` as not regurgitated;
#'   `"drop"` treats `NA` as regurgitated.
#'
#' @return `dat` with regurgitated predators removed.
#' @export
drop_invalid <- function(dat, na_regurgitated = "keep") {
  if (!na_regurgitated %in% c("keep", "drop")) {
    stop('`na_regurgitated` must be "keep" or "drop"')
  }

  n_before <- dplyr::n_distinct(dat$tbl_predator_information_id)

  dat <- dat |>
    dplyr::mutate(
      .regurg_flag = dplyr::case_when(
        regurgitated >= 1 ~ TRUE,
        regurgitated == 0 ~ FALSE,
        is.na(regurgitated) & na_regurgitated == "drop" ~ TRUE,
        TRUE ~ FALSE
      )
    )

  n_dropped_by_country <- dat |>
    dplyr::distinct(tbl_predator_information_id, country, .regurg_flag) |>
    dplyr::filter(.regurg_flag) |>
    dplyr::count(country, name = "n_dropped")

  n_na_regurg <- dat |>
    dplyr::distinct(tbl_predator_information_id, regurgitated) |>
    dplyr::filter(is.na(regurgitated)) |>
    nrow()

  drop_ids <- dat |>
    dplyr::filter(.regurg_flag) |>
    dplyr::pull(tbl_predator_information_id) |>
    unique()

  dat <- dat |>
    dplyr::filter(!tbl_predator_information_id %in% drop_ids) |>
    dplyr::select(-.regurg_flag)

  n_after <- dplyr::n_distinct(dat$tbl_predator_information_id)
  n_dropped <- n_before - n_after
  pct <- function(x) sprintf("%4.1f%%", 100 * x / n_before)

  na_msg <- if (na_regurgitated == "keep") {
    "regurgitated == NA assumed not regurgitated (n = {n_na_regurg} kept)"
  } else {
    "regurgitated == NA assumed regurgitated (n = {n_na_regurg} dropped)"
  }

  cli::cli_inform(c(
    "drop_invalid(): {n_before} -> {n_after} predator{?s} ({n_dropped} dropped, {pct(n_dropped)})",
    "i" = "regurgitated >= 1 assumed regurgitated",
    "i" = na_msg,
    "i" = "Dropped by country:"
  ))

  if (nrow(n_dropped_by_country) == 0) {
    message("  none")
  } else {
    print(data.frame(
      country          = n_dropped_by_country$country,
      n                = n_dropped_by_country$n_dropped,
      percent_of_total = pct(n_dropped_by_country$n_dropped)
    ))
  }

  dat
}
