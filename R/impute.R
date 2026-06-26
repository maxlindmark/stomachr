#' Impute missing prey and predator sizes
#'
#' Estimates missing prey weight and/or length via L/W parameters or observed
#' means, and estimates missing predator weight from length. Calls the internal
#' [add_lw()] helper to attach L/W parameters before imputation.
#'
#' @param dat Tibble from [add_taxonomy()].
#' @param which One of `"both"` (default), `"prey"`, or `"pred"`.
#' @param method One of `"lw_params"` (default) or `"observations"`.
#' @param size One of `"both"` (default), `"weight"`, or `"length"`.
#' @param fill_if_no_size If `TRUE` (default), prey records with neither weight
#'   nor length borrow a size from the same stomach, same predator-prey pair,
#'   or global species mean, then apply L/W.
#'
#' @return `dat` with imputed size columns and `prey_lw_source` /
#'   `pred_lw_source` provenance columns. Internal L/W parameter columns are
#'   dropped.
#' @export
impute_size <- function(dat,
                        which = c("both", "prey", "pred"),
                        method = c("lw_params", "observations"),
                        size = c("both", "weight", "length"),
                        fill_if_no_size = TRUE) {
  which <- match.arg(which)
  method <- match.arg(method)
  size <- match.arg(size)

  do_prey <- which %in% c("both", "prey")
  do_pred <- which %in% c("both", "pred")
  do_weight <- size %in% c("both", "weight")
  do_length <- size %in% c("both", "length")

  dat <- add_lw(dat)

  # ---- Prey imputation -----------------------------------------------------
  if (do_prey) {
    n_prey_total <- sum(!is.na(dat$aphia_id_prey))

    dat <- dat |>
      dplyr::mutate(
        prey_lw_source = dplyr::case_when(
          !is.na(aphia_id_prey) & !is.na(prey_length) & !is.na(prey_weight_ind) ~ "observed",
          !is.na(aphia_id_prey) & !is.na(prey_length) ~ "weight_to_estimate",
          !is.na(aphia_id_prey) & !is.na(prey_weight_ind) ~ "length_to_estimate",
          !is.na(aphia_id_prey) ~ "both_to_estimate",
          TRUE ~ NA_character_
        )
      )

    # Compute observation hierarchy means before any imputation (avoids circularity).
    if (fill_if_no_size) {
      obs1 <- dat |>
        dplyr::filter(!is.na(aphia_id_prey)) |>
        dplyr::summarise(
          obs1_length = mean(prey_length, na.rm = TRUE),
          obs1_weight = mean(prey_weight_ind, na.rm = TRUE),
          .by = c(tbl_predator_information_id, aphia_id_prey)
        )
      obs2 <- dat |>
        dplyr::filter(!is.na(aphia_id_prey)) |>
        dplyr::summarise(
          obs2_length = mean(prey_length, na.rm = TRUE),
          obs2_weight = mean(prey_weight_ind, na.rm = TRUE),
          .by = c(aphia_id_predator, aphia_id_prey)
        )
      obs3 <- dat |>
        dplyr::filter(!is.na(aphia_id_prey)) |>
        dplyr::summarise(
          obs3_length = mean(prey_length, na.rm = TRUE),
          obs3_weight = mean(prey_weight_ind, na.rm = TRUE),
          .by = aphia_id_prey
        )
    }

    if (method == "lw_params") {
      if (do_weight) {
        dat <- dat |>
          dplyr::mutate(
            prey_weight_ind = dplyr::if_else(
              is.na(prey_weight_ind) & !is.na(prey_length),
              lw_a * prey_length^lw_b,
              prey_weight_ind
            ),
            prey_lw_source = dplyr::if_else(
              prey_lw_source == "weight_to_estimate",
              "weight_estimated_lw", prey_lw_source
            )
          )
      }
      if (do_length) {
        dat <- dat |>
          dplyr::mutate(
            prey_length = dplyr::if_else(
              is.na(prey_length) & !is.na(prey_weight_ind),
              (prey_weight_ind / lw_a)^(1 / lw_b),
              prey_length
            ),
            prey_lw_source = dplyr::if_else(
              prey_lw_source == "length_to_estimate",
              "length_estimated_lw", prey_lw_source
            )
          )
      }
    } else {
      wg1 <- dat |>
        dplyr::filter(!is.na(aphia_id_prey)) |>
        dplyr::summarise(
          wg1_length = mean(prey_length, na.rm = TRUE),
          wg1_weight = mean(prey_weight_ind, na.rm = TRUE),
          .by = c(tbl_predator_information_id, aphia_id_prey)
        )
      wg2 <- dat |>
        dplyr::filter(!is.na(aphia_id_prey)) |>
        dplyr::summarise(
          wg2_length = mean(prey_length, na.rm = TRUE),
          wg2_weight = mean(prey_weight_ind, na.rm = TRUE),
          .by = c(aphia_id_predator, aphia_id_prey)
        )
      wg3 <- dat |>
        dplyr::filter(!is.na(aphia_id_prey)) |>
        dplyr::summarise(
          wg3_length = mean(prey_length, na.rm = TRUE),
          wg3_weight = mean(prey_weight_ind, na.rm = TRUE),
          .by = aphia_id_prey
        )

      dat <- dat |>
        dplyr::left_join(wg1, by = c("tbl_predator_information_id", "aphia_id_prey")) |>
        dplyr::left_join(wg2, by = c("aphia_id_predator", "aphia_id_prey")) |>
        dplyr::left_join(wg3, by = "aphia_id_prey")

      if (do_weight) {
        dat <- dat |>
          dplyr::mutate(
            .wg_weight = dplyr::coalesce(wg1_weight, wg2_weight, wg3_weight),
            prey_lw_source = dplyr::if_else(
              prey_lw_source %in% c("weight_to_estimate", "both_to_estimate") & !is.na(.wg_weight),
              "weight_estimated_obs", prey_lw_source
            ),
            prey_weight_ind = dplyr::if_else(is.na(prey_weight_ind), .wg_weight, prey_weight_ind)
          ) |>
          dplyr::select(-.wg_weight)
      }
      if (do_length) {
        dat <- dat |>
          dplyr::mutate(
            .wg_length = dplyr::coalesce(wg1_length, wg2_length, wg3_length),
            prey_lw_source = dplyr::if_else(
              prey_lw_source %in% c("length_to_estimate", "both_to_estimate") & !is.na(.wg_length),
              "length_estimated_obs", prey_lw_source
            ),
            prey_length = dplyr::if_else(is.na(prey_length), .wg_length, prey_length)
          ) |>
          dplyr::select(-.wg_length)
      }

      dat <- dat |>
        dplyr::select(
          -wg1_length, -wg1_weight, -wg2_length, -wg2_weight,
          -wg3_length, -wg3_weight
        )
    }

    if (fill_if_no_size) {
      dat <- dat |>
        dplyr::left_join(obs1, by = c("tbl_predator_information_id", "aphia_id_prey")) |>
        dplyr::left_join(obs2, by = c("aphia_id_predator", "aphia_id_prey")) |>
        dplyr::left_join(obs3, by = "aphia_id_prey") |>
        dplyr::mutate(
          .size_src = dplyr::case_when(
            prey_lw_source != "both_to_estimate" ~ NA_character_,
            !is.na(obs1_weight) ~ "weight_from_same_stomach_then_lw",
            !is.na(obs1_length) ~ "length_from_same_stomach_then_lw",
            !is.na(obs2_weight) ~ "weight_from_same_pred_prey_pair_then_lw",
            !is.na(obs2_length) ~ "length_from_same_pred_prey_pair_then_lw",
            !is.na(obs3_weight) ~ "weight_from_mean_prey_size_then_lw",
            !is.na(obs3_length) ~ "length_from_mean_prey_size_then_lw",
            TRUE ~ NA_character_
          ),
          .fill_weight = dplyr::case_when(
            .size_src == "weight_from_same_stomach_then_lw" ~ obs1_weight,
            .size_src == "weight_from_same_pred_prey_pair_then_lw" ~ obs2_weight,
            .size_src == "weight_from_mean_prey_size_then_lw" ~ obs3_weight
          ),
          .fill_length = dplyr::case_when(
            .size_src == "length_from_same_stomach_then_lw" ~ obs1_length,
            .size_src == "length_from_same_pred_prey_pair_then_lw" ~ obs2_length,
            .size_src == "length_from_mean_prey_size_then_lw" ~ obs3_length
          ),
          prey_weight_ind = dplyr::if_else(
            prey_lw_source == "both_to_estimate" & !is.na(.fill_weight),
            .fill_weight, prey_weight_ind
          ),
          prey_length = dplyr::if_else(
            prey_lw_source == "both_to_estimate" & !is.na(.fill_length),
            .fill_length, prey_length
          ),
          prey_lw_source = dplyr::if_else(
            prey_lw_source == "both_to_estimate" & !is.na(.size_src),
            .size_src, prey_lw_source
          )
        ) |>
        dplyr::mutate(
          prey_weight_ind = dplyr::if_else(
            grepl("^length_from_", prey_lw_source) & is.na(prey_weight_ind),
            lw_a * prey_length^lw_b,
            prey_weight_ind
          ),
          prey_length = dplyr::if_else(
            grepl("^weight_from_", prey_lw_source) & is.na(prey_length),
            (prey_weight_ind / lw_a)^(1 / lw_b),
            prey_length
          )
        ) |>
        dplyr::select(
          -obs1_length, -obs1_weight, -obs2_length, -obs2_weight,
          -obs3_length, -obs3_weight, -.fill_weight, -.fill_length,
          -.size_src
        )
    }

    dat <- dat |>
      dplyr::mutate(prey_weight_all_ind = prey_weight_ind * count)
  }

  # ---- Predator weight estimation ------------------------------------------
  if (do_pred) {
    dat <- dat |>
      dplyr::mutate(
        ind_weight_est = dplyr::if_else(
          is.na(ind_wgt) & !is.na(pred_length),
          pred_lw_a * pred_length^pred_lw_b,
          NA_real_
        )
      )
  }

  dat <- dat |> dplyr::select(-lw_a, -lw_b, -pred_lw_a, -pred_lw_b)

  # ---- Message -------------------------------------------------------------
  lw_order <- c(
    "species", "family", "order", "class", "phylum",
    "universal (a=0.01, b=3)"
  )

  B <- "├── "
  L <- "└── "
  V <- "│   "

  fix_last <- function(lines) {
    if (length(lines) > 0) lines[length(lines)] <- sub(B, L, lines[length(lines)], fixed = TRUE)
    lines
  }

  sections <- list()

  if (do_prey) {
    src_counts <- dat |>
      dplyr::filter(!is.na(aphia_id_prey)) |>
      dplyr::count(prey_lw_source) |>
      tibble::deframe()

    cnt <- function(key) {
      v <- src_counts[key]
      if (is.na(v)) 0L else as.integer(v)
    }
    pct <- function(key) sprintf("%.1f%%", 100 * cnt(key) / n_prey_total)
    np <- function(key) sprintf("%d (%s)", cnt(key), pct(key))
    np_n <- function(n_val) sprintf("%d (%.1f%%)", n_val, 100 * n_val / n_prey_total)
    bsub <- function(label, key, prefix = V) {
      if (cnt(key) > 0) paste0(prefix, B, label, ": ", np(key)) else character(0)
    }

    n_one_size <- cnt("weight_estimated_lw") + cnt("length_estimated_lw") +
      cnt("weight_estimated_obs") + cnt("length_estimated_obs")

    n_no_size_rescued <- cnt("weight_from_same_stomach_then_lw") +
      cnt("weight_from_same_pred_prey_pair_then_lw") +
      cnt("weight_from_mean_prey_size_then_lw") +
      cnt("length_from_same_stomach_then_lw") +
      cnt("length_from_same_pred_prey_pair_then_lw") +
      cnt("length_from_mean_prey_size_then_lw")

    one_size_sub <- fix_last(c(
      bsub("had length, estimated weight via L/W", "weight_estimated_lw"),
      bsub("had weight, estimated length via L/W", "length_estimated_lw"),
      bsub("had length, estimated weight from obs", "weight_estimated_obs"),
      bsub("had weight, estimated length from obs", "length_estimated_obs")
    ))
    no_size_sub <- fix_last(c(
      bsub("same stomach: mean weight -> length via L/W", "weight_from_same_stomach_then_lw"),
      bsub("same pred-prey pair: mean weight -> length via L/W", "weight_from_same_pred_prey_pair_then_lw"),
      bsub("global species mean: mean weight -> length via L/W", "weight_from_mean_prey_size_then_lw"),
      bsub("same stomach: mean length -> weight via L/W", "length_from_same_stomach_then_lw"),
      bsub("same pred-prey pair: mean length -> weight via L/W", "length_from_same_pred_prey_pair_then_lw"),
      bsub("global species mean: mean length -> weight via L/W", "length_from_mean_prey_size_then_lw")
    ))

    middle <- c(
      if (n_one_size > 0) {
        c(
          paste0(B, "one size recorded, other estimated: ", np_n(n_one_size)),
          one_size_sub
        )
      },
      if (n_no_size_rescued > 0) {
        c(
          paste0(B, "no size recorded, imputed from other records: ", np_n(n_no_size_rescued)),
          no_size_sub
        )
      }
    )

    prey_lw_src <- dat |>
      dplyr::filter(!is.na(aphia_id_prey)) |>
      dplyr::distinct(aphia_id_prey, lw_source) |>
      dplyr::count(lw_source) |>
      dplyr::arrange(match(lw_source, lw_order)) |>
      dplyr::mutate(label = paste0(lw_source, ": ", n)) |>
      dplyr::pull(label) |>
      paste(collapse = ", ")

    prey_lines <- stats::setNames(
      c(
        paste0(B, "both weight and length recorded: ", np("observed")),
        middle,
        paste0(
          L, "no size info in any record of that species: ", np("both_to_estimate"),
          " (diet composition only, weight unusable)"
        )
      ),
      rep(" ", 2L + length(middle))
    )

    sections$prey <- c(
      stats::setNames(
        paste0("Prey: ", n_prey_total, " records | L/W params (unique AphiaIDs): ", prey_lw_src),
        " "
      ),
      prey_lines
    )
  }

  if (do_pred) {
    n_pred_total <- nrow(dat)
    n_both_obs <- sum(!is.na(dat$ind_wgt) & !is.na(dat$pred_length))
    n_wgt_only <- sum(!is.na(dat$ind_wgt) & is.na(dat$pred_length))
    n_est <- sum(!is.na(dat$ind_weight_est))
    n_neither <- sum(is.na(dat$ind_wgt) & is.na(dat$pred_length))
    ppct <- function(n) sprintf("%d (%.1f%%)", n, 100 * n / n_pred_total)

    pred_lw_src <- dat |>
      dplyr::filter(!is.na(aphia_id_predator)) |>
      dplyr::distinct(aphia_id_predator, pred_lw_source) |>
      dplyr::count(pred_lw_source) |>
      dplyr::arrange(match(pred_lw_source, lw_order)) |>
      dplyr::mutate(label = paste0(pred_lw_source, ": ", n)) |>
      dplyr::pull(label) |>
      paste(collapse = ", ")

    est_src_counts <- dat |>
      dplyr::filter(!is.na(ind_weight_est)) |>
      dplyr::count(pred_lw_source) |>
      tibble::deframe()
    ecnt <- function(key) {
      v <- est_src_counts[key]
      if (is.na(v)) 0L else as.integer(v)
    }

    est_sub <- fix_last(Filter(
      \(x) length(x) > 0,
      lapply(lw_order, \(lvl) {
        n <- ecnt(lvl)
        if (n > 0) paste0(V, B, lvl, ": ", ppct(n)) else character(0)
      })
    ))

    pred_lines <- fix_last(c(
      paste0(B, "weight and length observed: ", ppct(n_both_obs)),
      paste0(B, "weight observed, length missing: ", ppct(n_wgt_only)),
      if (n_est > 0) {
        c(
          paste0(B, "length observed, weight estimated via L/W: ", ppct(n_est)),
          est_sub
        )
      },
      if (n_neither > 0) {
        paste0(B, "no weight or length: ", ppct(n_neither))
      }
    ))

    sections$pred <- c(
      stats::setNames(
        paste0("Predator: ", n_pred_total, " rows | L/W params (unique AphiaIDs): ", pred_lw_src),
        " "
      ),
      stats::setNames(pred_lines, rep(" ", length(pred_lines)))
    )
  }

  cli::cli_inform(c(
    "impute_size(): which = {.val {which}} | method = {.val {method}} | size = {.val {size}} | fill_if_no_size = {.val {fill_if_no_size}}",
    unlist(sections, use.names = TRUE)
  ))

  dat |>
    dplyr::mutate(
      predator_weight           = dplyr::coalesce(ind_wgt, ind_weight_est),
      predator_weight_estimated = is.na(ind_wgt) & !is.na(ind_weight_est)
    )
}
