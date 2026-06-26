# Internal helper called by impute_size(). Adds L/W parameters for both prey
# and predator via hierarchical fallback: species -> family -> order -> class
# -> phylum -> universal (a = 0.01, b = 3).
#
# Uses the bundled lw_params table (data/lw_params.rda).
#
# Adds prey columns:  lw_a, lw_b, lw_source
# Adds pred columns:  pred_lw_a, pred_lw_b, pred_lw_source
#
#' @noRd
add_lw <- function(dat) {
  lw_sp <- lw_params |>
    dplyr::filter(lw_source == "species") |>
    dplyr::select(aphia_id, lw_a, lw_b, lw_source)

  dat <- dat |> dplyr::left_join(lw_sp, by = c("aphia_id_prey" = "aphia_id"))

  for (lvl in c("family", "order", "class", "phylum")) {
    col <- paste0("prey_", lvl)
    lw_fb <- lw_params |>
      dplyr::filter(lw_source == lvl) |>
      dplyr::select(dplyr::all_of(c(lvl, "lw_a", "lw_b", "lw_source"))) |>
      dplyr::rename_with(\(x) paste0(x, "_fb"), -dplyr::all_of(lvl)) |>
      dplyr::rename(!!col := dplyr::all_of(lvl))

    dat <- dat |>
      dplyr::left_join(lw_fb, by = col) |>
      dplyr::mutate(
        lw_source = dplyr::if_else(is.na(lw_a) & !is.na(lw_a_fb), lw_source_fb, lw_source),
        lw_a      = dplyr::coalesce(lw_a, lw_a_fb),
        lw_b      = dplyr::coalesce(lw_b, lw_b_fb)
      ) |>
      dplyr::select(-lw_a_fb, -lw_b_fb, -lw_source_fb)
  }

  dat <- dat |>
    dplyr::mutate(
      lw_source = dplyr::if_else(
        is.na(lw_a) & !is.na(aphia_id_prey), "universal (a=0.01, b=3)", lw_source
      ),
      lw_a = dplyr::if_else(is.na(lw_a), 0.01, lw_a),
      lw_b = dplyr::if_else(is.na(lw_b), 3, lw_b)
    )

  # Run the hierarchy on a small distinct-predator table, then join back.
  pred_taxa <- dat |>
    dplyr::select(
      aphia_id_predator, predator_family, predator_order,
      predator_class, predator_phylum
    ) |>
    dplyr::distinct(aphia_id_predator, .keep_all = TRUE)

  pred_taxa <- pred_taxa |>
    dplyr::left_join(
      lw_params |>
        dplyr::filter(lw_source == "species") |>
        dplyr::select(
          aphia_id,
          pred_lw_a      = lw_a,
          pred_lw_b      = lw_b,
          pred_lw_source = lw_source
        ),
      by = c("aphia_id_predator" = "aphia_id")
    )

  pred_lvls <- c("family", "order", "class", "phylum")
  pred_cols <- paste0("predator_", pred_lvls)

  for (i in seq_along(pred_lvls)) {
    lvl <- pred_lvls[i]
    col <- pred_cols[i]
    fb <- lw_params |>
      dplyr::filter(lw_source == lvl) |>
      dplyr::select(dplyr::all_of(lvl), .a = lw_a, .b = lw_b, .src = lw_source) |>
      dplyr::rename(!!col := dplyr::all_of(lvl))

    pred_taxa <- pred_taxa |>
      dplyr::left_join(fb, by = col) |>
      dplyr::mutate(
        pred_lw_source = dplyr::if_else(is.na(pred_lw_a) & !is.na(.a), .src, pred_lw_source),
        pred_lw_a      = dplyr::coalesce(pred_lw_a, .a),
        pred_lw_b      = dplyr::coalesce(pred_lw_b, .b)
      ) |>
      dplyr::select(-.a, -.b, -.src)
  }

  pred_taxa <- pred_taxa |>
    dplyr::mutate(
      pred_lw_source = dplyr::if_else(
        is.na(pred_lw_a), "universal (a=0.01, b=3)", pred_lw_source
      ),
      pred_lw_a = dplyr::if_else(is.na(pred_lw_a), 0.01, pred_lw_a),
      pred_lw_b = dplyr::if_else(is.na(pred_lw_b), 3, pred_lw_b)
    )

  dat |>
    dplyr::left_join(
      pred_taxa |> dplyr::select(aphia_id_predator, pred_lw_a, pred_lw_b, pred_lw_source),
      by = "aphia_id_predator"
    )
}
