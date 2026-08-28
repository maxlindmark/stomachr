#' Resolve pooled predator records to one row per predator
#'
#' `Number` on a `PredatorInformation.csv` record can be greater than 1 --
#' DATSU documents it as "Number of specimens taken for stomach analyses
#' (pooled samples)". A pooled record's `pred_length`/`predator_weight`
#' describe one representative fish, but the prey rows linked to that same
#' `tbl_predator_information_id` describe the pooled group's combined diet,
#' not that one fish's. Downstream code that assumes one row is one predator
#' (diet-per-individual averages, `n_distinct(tbl_predator_information_id)`
#' counts, prey-weight-to-predator-weight ratios) is silently wrong for the
#' pooled fraction of the data unless this is resolved one way or another.
#' See `vignette("known-issues", package = "stomachr")` for the evidence.
#'
#' @param dat Tibble from [add_taxonomy()]. Must be called before
#'   [drop_invalid()] and [impute_size()] -- `drop_invalid()`'s
#'   `regurgitated >= 1` rule needs one-fish-per-row to mean what it says
#'   (see `regurgitated` below), and `impute_size()`'s weight fallbacks
#'   should see the per-individual view, not the pooled one.
#' @param method One of `"uncount"` (default) or `"filter"`.
#'   - `"uncount"`: expands each pooled record (`Number > 1`) into `Number`
#'     rows, one per implied individual, each carrying a distinct pseudo
#'     `tbl_predator_information_id` (`"<original_id>_<copy>"`). `count` is
#'     apportioned across copies so the total stays an integer and sums back
#'     to the original (e.g. `count = 7, Number = 3` -> `3, 2, 2`); `weight`
#'     is recomputed from the apportioned count and the unchanged per-item
#'     `prey_weight_ind`, so it also sums back exactly to the original.
#'     `regurgitated` (also a count, DATSU: "Number of stomachs
#'     regurgitated") is apportioned the same way but capped at 0/1 per
#'     copy -- for `Number = 10, Regurgitated = 3`, 3 of the 10 copies get
#'     `regurgitated = 1` and 7 get `0`, so a subsequent `drop_invalid()`
#'     drops exactly the right fraction instead of the whole group or none
#'     of it. `stomach_empty` (DATSU: "Number of empty stomachs in the
#'     sample") is also a per-pool count, but unlike `regurgitated` an empty
#'     individual gets its own no-prey copy rather than a flag on an
#'     existing one: `count`/`weight`/`other_count` are apportioned across
#'     `Number - stomach_empty` fed copies instead of `Number`, and
#'     `stomach_empty` further copies are added with every prey-level field
#'     `NA` and `stomach_status = "empty"`. Predator-level fields (`pred_length`, `predator_weight`, etc.)
#'     are unchanged and repeated across copies -- these are `Number`
#'     identical copies of one averaged fish, not independent observations.
#'     Fine for totals and for correctly weighting a pooled group's diet
#'     pattern by how many fish it represents; not fine if something later
#'     computes per-individual *variance* and would treat the copies as
#'     independent samples.
#'   - `"filter"`: drops every record with `Number > 1` outright, keeping
#'     only genuine single-fish records. Simpler, loses the pooled fraction
#'     of the data (about 2.4% of predator records) rather than resolving it.
#'
#'   Either is defensible; doing neither is not -- pick the one that fits
#'   the analysis rather than treating every `tbl_predator_information_id`
#'   as one fish by default.
#'
#' @return `dat` with one row group per predator individual, an added
#'   logical `unpooled` column (`TRUE` for rows created by `method =
#'   "uncount"`, always `FALSE` under `method = "filter"`), and `number`
#'   reset to `1` throughout.
#' @export
unpool_predators <- function(dat, method = c("uncount", "filter")) {
  method <- match.arg(method)

  n_number_na <- dplyr::n_distinct(dat$tbl_predator_information_id[is.na(dat$number)])
  n_pred_before <- dplyr::n_distinct(dat$tbl_predator_information_id)
  n_pooled <- dplyr::n_distinct(
    dat$tbl_predator_information_id[!is.na(dat$number) & dat$number > 1]
  )

  is_pooled <- !is.na(dat$number) & dat$number > 1

  if (method == "filter") {
    dat <- dat[!is_pooled, ]
    dat$unpooled <- FALSE

    cli::cli_inform(c(
      "{cli::col_cyan('unpool_predators()')}: {.val filter}",
      "i" = "{fmt_n(n_pred_before)} predator individuals -> {fmt_n(n_pred_before - n_pooled)} kept, {fmt_n(n_pooled)} pooled ({sprintf('%.1f%%', 100 * n_pooled / n_pred_before)}) dropped",
      if (n_number_na > 0) c("!" = "{fmt_n(n_number_na)} predator{cli::qty(n_number_na)} record{?s} had `Number` = NA, treated as already-individual and kept"),
      " " = ""
    ))
    return(dat)
  }

  # method == "uncount" ------------------------------------------------------
  not_pooled <- dat[!is_pooled, ]
  not_pooled$unpooled <- FALSE
  # expanded's tbl_predator_information_id becomes character below (paste0
  # with the copy index); match that here so the final bind_rows() doesn't
  # fail on a numeric/character type mismatch when the input id is numeric
  # (as it is for real ICES data, where this is a database key).
  not_pooled$tbl_predator_information_id <- as.character(not_pooled$tbl_predator_information_id)

  pooled <- dat[is_pooled, ]

  if (nrow(pooled) == 0) {
    not_pooled$number <- 1L
    return(not_pooled)
  }

  # `StomachEmpty` (carried through as `stomach_empty`, DATSU: "Number of
  # empty stomachs in the sample") is a per-pool count, like `regurgitated`:
  # only `number - stomach_empty` of a pool's individuals actually
  # contributed the prey rows attached to this record, so count/weight are
  # apportioned across that fed count, not `number`. The `stomach_empty`
  # individuals themselves get their own no-prey copies below, since an
  # empty individual needs a whole separate row, not a flag on an existing
  # one (unlike `regurgitated`).
  stomach_empty <- if ("stomach_empty" %in% names(pooled)) {
    pmin(dplyr::coalesce(pooled$stomach_empty, 0), pooled$number)
  } else {
    rep(0, nrow(pooled))
  }
  n_fed <- pooled$number - stomach_empty

  rep_idx <- rep(seq_len(nrow(pooled)), times = n_fed)
  copy_idx <- unlist(lapply(n_fed, seq_len), use.names = FALSE)

  expanded <- pooled[rep_idx, ]
  expanded$.copy_idx <- copy_idx
  expanded$.n_fed <- n_fed[rep_idx]

  expanded <- expanded |>
    dplyr::mutate(
      count_base = count %/% .n_fed,
      count_remainder = count %% .n_fed,
      count = dplyr::if_else(
        is.na(count),
        NA_integer_,
        as.integer(count_base + dplyr::if_else(.copy_idx <= count_remainder, 1L, 0L))
      ),
      weight = dplyr::if_else(
        is.na(prey_weight_ind) | is.na(count),
        weight / .n_fed,
        prey_weight_ind * count
      ),
      other_count_base = other_count %/% .n_fed,
      other_count_remainder = other_count %% .n_fed,
      other_count = dplyr::if_else(
        is.na(other_count),
        NA_integer_,
        as.integer(other_count_base + dplyr::if_else(.copy_idx <= other_count_remainder, 1L, 0L))
      ),
      other_wgt = other_wgt / .n_fed,
      # Regurgitated is a per-group count (DATSU: "Number of stomachs
      # regurgitated"), not a per-individual flag -- apportion it the same
      # direction as count/other_count, but capped at one regurgitated
      # "slot" per copy (a single implied fish is either regurgitated or
      # not, never regurgitated more than once). Which specific copies get
      # marked is arbitrary, same as which copies get the extra prey item
      # in the count apportionment above -- there's no way to know which
      # implied fish were the regurgitated ones.
      regurgitated = dplyr::if_else(
        is.na(regurgitated),
        NA_real_,
        dplyr::if_else(.copy_idx <= regurgitated, 1, 0)
      ),
      tbl_predator_information_id = paste0(tbl_predator_information_id, "_", .copy_idx),
      unpooled = TRUE
    ) |>
    dplyr::select(-count_base, -count_remainder, -other_count_base, -other_count_remainder, -.copy_idx, -.n_fed)

  # `stomach_empty` individuals: one no-prey row each. A pooled record can
  # have several original prey-item rows (one per prey species) -- reduce to
  # one row per predator first, so the empty copies don't duplicate per
  # prey item, then clear every prey-level field.
  prey_cols <- intersect(names(pooled), c(
    "tbl_prey_information_id", "aphia_id_prey", "ident_met", "digestion_stage",
    "grav_method", "sub_factor", "prey_sequence", "count", "unit_wgt", "weight",
    "unit_lngt", "prey_length", "other_items", "other_count", "other_wgt",
    "analysing_org", "count_censored", "prey_weight_ind",
    "prey_scientific_name", "prey_class", "prey_order", "prey_family", "prey_phylum"
  ))

  has_stomach_empty <- stomach_empty > 0
  if (any(has_stomach_empty)) {
    empty_base <- pooled[has_stomach_empty, ]
    empty_base$.stomach_empty <- stomach_empty[has_stomach_empty]
    empty_base <- dplyr::distinct(empty_base, tbl_predator_information_id, .keep_all = TRUE)

    se_rep_idx <- rep(seq_len(nrow(empty_base)), times = empty_base$.stomach_empty)
    se_copy_idx <- unlist(lapply(empty_base$.stomach_empty, seq_len), use.names = FALSE)

    empty_expanded <- empty_base[se_rep_idx, ]
    empty_expanded[prey_cols] <- NA
    empty_expanded <- empty_expanded |>
      dplyr::mutate(
        stomach_status = "empty",
        regurgitated = 0,
        tbl_predator_information_id = paste0(tbl_predator_information_id, "_stomEmpty", se_copy_idx),
        unpooled = TRUE,
        .stomach_empty = NULL
      )

    expanded <- dplyr::bind_rows(expanded, empty_expanded)
  }

  dat <- dplyr::bind_rows(not_pooled, expanded)
  dat$number <- 1L

  n_pred_after <- dplyr::n_distinct(dat$tbl_predator_information_id)

  cli::cli_inform(c(
    "{cli::col_cyan('unpool_predators()')}: {.val uncount}",
    "i" = "{fmt_n(n_pred_before)} predator individuals ({fmt_n(n_pooled)} pooled) -> {fmt_n(n_pred_after)} rows, one per implied individual",
    "!" = "Pooled rows became {cli::qty(0)}identical, non-independent copies of one averaged fish (`unpooled` column marks them) -- fine for totals, not for per-individual variance",
    if (n_number_na > 0) c("!" = "{fmt_n(n_number_na)} predator{cli::qty(n_number_na)} record{?s} had `Number` = NA, treated as already-individual and left as-is"),
    " " = ""
  ))

  dat
}
