#' Drop regurgitated stomachs and count usable stomachs per record
#'
#' A predator record can describe a pooled sample of `number` fish, and
#' `regurgitated` is the number of those stomachs that were regurgitated.
#' This function adds:
#'
#' - `n_stomachs`: usable stomachs behind the record, `number - regurgitated`
#'   (`number = NA` is treated as `1`).
#' - `n_empty`: how many of those `n_stomachs` were empty. `n_stomachs` if
#'   the record has no prey (`stomach_status == "empty"`), otherwise
#'   `stomach_empty` capped at `n_stomachs - 1`; `0` for a single fish with
#'   prey; `NA` for a pooled record with prey and no `stomach_empty` reported.
#'
#' Records with no usable stomachs left (`n_stomachs <= 0`) are dropped. For
#' single-fish records this is the same as dropping `regurgitated >= 1`; a
#' pool of 10 with 3 regurgitated is kept with `n_stomachs = 7`.
#'
#' Pooled records stay one row each. Use `n_stomachs` as the denominator for
#' per-fish quantities (e.g. `sum(weight) / sum(n_stomachs)`), or as
#' `offset(log(n_stomachs))` in a model; see
#' `vignette("example-workflow", package = "stomachr")`. To expand pools into
#' one row per implied fish instead, follow with [unpool_predators()].
#'
#' @param dat Tibble from [join_stomach_data()] or [add_taxonomy()].
#' @param na_regurgitated `"keep"` (default) treats `NA` as not regurgitated;
#'   `"drop"` drops records with `regurgitated = NA`.
#'
#' @return `dat` with regurgitated-only records removed and `n_stomachs` and
#'   `n_empty` columns added.
#' @export
drop_invalid <- function(dat, na_regurgitated = "keep") {
  if (!na_regurgitated %in% c("keep", "drop")) {
    stop('`na_regurgitated` must be "keep" or "drop"')
  }

  n_before <- dplyr::n_distinct(dat$tbl_predator_information_id)

  stomach_empty <- if ("stomach_empty" %in% names(dat)) dat$stomach_empty else NA_real_

  dat <- dat |>
    dplyr::mutate(
      n_stomachs = pmax(dplyr::coalesce(number, 1) - dplyr::coalesce(regurgitated, 0), 0),
      n_empty = dplyr::case_when(
        stomach_status == "empty" ~ n_stomachs,
        n_stomachs <= 1 ~ 0,
        TRUE ~ pmin(stomach_empty, n_stomachs - 1)
      ),
      .drop_flag = n_stomachs <= 0 | (is.na(regurgitated) & na_regurgitated == "drop")
    )

  pred <- dplyr::distinct(dat, tbl_predator_information_id, country, number, regurgitated, n_stomachs, .drop_flag)

  n_dropped_by_country <- pred |>
    dplyr::filter(.drop_flag) |>
    dplyr::count(country, name = "n_dropped")

  n_na_regurg <- sum(is.na(pred$regurgitated))
  kept <- pred[!pred$.drop_flag, ]
  n_pools_reduced <- sum(kept$n_stomachs < dplyr::coalesce(kept$number, 1))
  n_stomachs_removed <- sum(dplyr::coalesce(kept$number, 1) - kept$n_stomachs)

  dat <- dat |>
    dplyr::filter(!.drop_flag) |>
    dplyr::select(-.drop_flag)

  n_after <- dplyr::n_distinct(dat$tbl_predator_information_id)
  n_dropped <- n_before - n_after
  pct <- function(x) sprintf("%4.1f%%", 100 * x / n_before)

  na_msg <- if (na_regurgitated == "keep") {
    "regurgitated == NA assumed not regurgitated (n = {fmt_n(n_na_regurg)} kept)"
  } else {
    "regurgitated == NA assumed regurgitated (n = {fmt_n(n_na_regurg)} dropped)"
  }

  cli::cli_inform(c(
    "{cli::col_cyan('drop_invalid()')}: {fmt_n(n_before)} -> {fmt_n(n_after)} predator {cli::qty(n_after)}record{?s} ({fmt_n(n_dropped)} dropped, {pct(n_dropped)})",
    "i" = "records dropped when every stomach is regurgitated (n_stomachs = number - regurgitated <= 0)",
    if (n_pools_reduced > 0) c("i" = "{fmt_n(n_pools_reduced)} pooled {cli::qty(n_pools_reduced)}record{?s} kept with {fmt_n(n_stomachs_removed)} regurgitated {cli::qty(n_stomachs_removed)}stomach{?s} subtracted from n_stomachs"),
    "i" = na_msg,
    "i" = "Dropped by country:"
  ))

  if (nrow(n_dropped_by_country) == 0) {
    message("  none")
  } else {
    print(data.frame(
      country          = n_dropped_by_country$country,
      n                = fmt_n(n_dropped_by_country$n_dropped),
      percent_of_total = pct(n_dropped_by_country$n_dropped)
    ))
  }
  message("")

  dat
}
