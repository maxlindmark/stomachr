#' Expand pooled predator records into one row per implied fish
#'
#' Optional. By default the pipeline keeps pooled records (`n_stomachs > 1`)
#' as one row each, and `n_stomachs` can be used as a denominator or model
#' offset. This function instead expands each pooled record into
#' `n_stomachs` synthetic individuals:
#'
#' - `n_stomachs - n_empty` fed copies share the record's prey. `count` and
#'   `other_count` are split as evenly as possible (`7` over 3 copies ->
#'   `3, 2, 2`); `weight` is `prey_weight_ind * count` where available,
#'   otherwise split evenly, as is `other_wgt`. Totals sum back to the
#'   original record.
#' - `n_empty` copies get no prey and `stomach_status = "empty"`. `n_empty =
#'   NA` is treated as `0`.
#'
#' Predator-level fields are repeated across copies. The even split is an
#' assumption, not data: totals and means are unchanged, but between-fish
#' variance is understated, the number of independent observations is
#' overstated, and frequency of occurrence is biased upward for the pooled
#' records.
#'
#' @param dat Tibble from [drop_invalid()].
#'
#' @return `dat` with pooled records expanded, `tbl_predator_information_id`
#'   as character (`"<id>_<copy>"` for copies), `number`, `n_stomachs` set to
#'   `1`, `n_empty` to `0`/`1`, `regurgitated` to `0` (unless `NA`), and an
#'   added logical `unpooled` column marking the copies.
#' @export
unpool_predators <- function(dat) {
  if (!all(c("n_stomachs", "n_empty") %in% names(dat))) {
    cli::cli_abort("Run {.fn drop_invalid} before {.fn unpool_predators}.")
  }

  is_pooled <- dat$n_stomachs > 1

  not_pooled <- dat[!is_pooled, ]
  not_pooled$unpooled <- FALSE
  not_pooled$tbl_predator_information_id <- as.character(not_pooled$tbl_predator_information_id)

  pooled <- dat[is_pooled, ]
  n_pooled <- dplyr::n_distinct(pooled$tbl_predator_information_id)

  if (n_pooled == 0) {
    cli::cli_inform(c(
      "{cli::col_cyan('unpool_predators()')}: no pooled records, nothing to expand",
      " " = ""
    ))
    return(not_pooled)
  }

  n_empty <- dplyr::coalesce(pooled$n_empty, 0)
  n_fed <- pooled$n_stomachs - n_empty
  n_empty_na <- dplyr::n_distinct(pooled$tbl_predator_information_id[is.na(pooled$n_empty)])

  rep_idx <- rep(seq_len(nrow(pooled)), times = n_fed)
  fed <- pooled[rep_idx, ]
  fed$.copy_idx <- as.integer(unlist(lapply(n_fed, seq_len), use.names = FALSE))
  fed$.n_fed <- n_fed[rep_idx]

  split_int <- function(x, n, i) {
    dplyr::if_else(is.na(x), NA_integer_, as.integer(x %/% n + (i <= x %% n)))
  }

  fed <- fed |>
    dplyr::mutate(
      count = split_int(count, .n_fed, .copy_idx),
      weight = dplyr::if_else(
        is.na(prey_weight_ind) | is.na(count),
        weight / .n_fed,
        prey_weight_ind * count
      ),
      other_count = split_int(other_count, .n_fed, .copy_idx),
      other_wgt = other_wgt / .n_fed,
      n_empty = 0,
      tbl_predator_information_id = paste0(tbl_predator_information_id, "_", .copy_idx)
    ) |>
    dplyr::select(-.copy_idx, -.n_fed)

  if ("prey_weight_all_ind" %in% names(fed)) {
    fed$prey_weight_all_ind <- fed$prey_weight_ind * fed$count
  }

  prey_cols <- intersect(names(pooled), c(
    "tbl_prey_information_id", "aphia_id_prey", "ident_met", "digestion_stage",
    "grav_method", "sub_factor", "prey_sequence", "count", "unit_wgt", "weight",
    "unit_lngt", "prey_length", "other_items", "other_count", "other_wgt",
    "analysing_org", "count_censored", "prey_weight_ind", "prey_weight_all_ind",
    "prey_lw_source", "lw_source", "prey_scientific_name", "prey_class",
    "prey_order", "prey_family", "prey_phylum"
  ))

  empty_base <- pooled
  empty_base$.n_empty <- n_empty
  empty_base <- dplyr::distinct(empty_base, tbl_predator_information_id, .keep_all = TRUE)
  empty_base <- empty_base[empty_base$.n_empty > 0, ]

  empty <- empty_base[rep(seq_len(nrow(empty_base)), times = empty_base$.n_empty), ]
  empty[prey_cols] <- NA
  empty <- empty |>
    dplyr::mutate(
      .copy_idx = as.integer(unlist(lapply(empty_base$.n_empty, seq_len), use.names = FALSE)),
      stomach_status = "empty",
      n_empty = 1,
      tbl_predator_information_id = paste0(tbl_predator_information_id, "_empty", .copy_idx)
    ) |>
    dplyr::select(-.copy_idx, -.n_empty)

  expanded <- dplyr::bind_rows(fed, empty) |>
    dplyr::mutate(
      number = 1,
      n_stomachs = 1,
      regurgitated = dplyr::if_else(is.na(regurgitated), NA_real_, 0),
      unpooled = TRUE
    )

  dat <- dplyr::bind_rows(not_pooled, expanded)

  n_copies <- dplyr::n_distinct(expanded$tbl_predator_information_id)

  cli::cli_inform(c(
    "{cli::col_cyan('unpool_predators()')}: {fmt_n(n_pooled)} pooled {cli::qty(n_pooled)}record{?s} -> {fmt_n(n_copies)} synthetic {cli::qty(n_copies)}individual{?s} ({.field unpooled} = TRUE)",
    "!" = "Prey are split evenly across copies: fine for totals and means, not for between-fish variance or frequency of occurrence",
    if (n_empty_na > 0) c("!" = "{fmt_n(n_empty_na)} pooled {cli::qty(n_empty_na)}record{?s} had n_empty = NA, treated as 0"),
    " " = ""
  ))

  dat
}
