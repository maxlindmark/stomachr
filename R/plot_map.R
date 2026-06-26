#' Plot sampling locations on a map
#'
#' Plots haul locations as points on a map of the North Sea.
#'
#' Requires the \pkg{rnaturalearth} package for the background land layer.
#'
#' @param dat Tibble from [trim_data()] or later. Must contain columns `lat`,
#'   `lon`, and `tbl_predator_information_id`.
#' @param color Column name (as a string) to colour points by. Defaults to
#'   `"predator_scientific_name"`.
#' @param facet Column name (as a string) to facet by. Defaults to
#'   `"predator_scientific_name"`.
#' @param species Character vector of species to include (filters on
#'   `predator_scientific_name`). Defaults to the top 8 predators by number of
#'   stomachs.
#' @param ncol Number of columns in `facet_wrap`.
#'
#' @return A `ggplot` object.
#' @export
plot_map <- function(dat,
                     color = "predator_scientific_name",
                     facet = "predator_scientific_name",
                     species = NULL,
                     ncol = 4) {
  if (!requireNamespace("rnaturalearth", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg rnaturalearth} is required for {.fn plot_map}.",
      "i" = "Install it with {.code install.packages('rnaturalearth')}."
    ))
  }

  pred_only <- dat |>
    dplyr::distinct(tbl_predator_information_id, .keep_all = TRUE) |>
    dplyr::filter(!is.na(lat), !is.na(lon))

  if (is.null(species)) {
    species <- pred_only |>
      dplyr::count(predator_scientific_name, sort = TRUE) |>
      dplyr::slice_head(n = 8) |>
      dplyr::pull(predator_scientific_name)
  }

  pred_only <- dplyr::filter(pred_only, predator_scientific_name %in% species)

  world <- rnaturalearth::ne_countries(scale = "small", returnclass = "sf")

  group_cols <- unique(c("lon", "lat", color, facet))
  plot_dat <- pred_only |>
    dplyr::count(dplyr::across(dplyr::all_of(group_cols)), name = "n_stomachs")

  color_scale <- if (is.numeric(plot_dat[[color]])) {
    ggplot2::scale_color_viridis_c()
  } else {
    ggplot2::scale_color_viridis_d()
  }

  ggplot2::ggplot() +
    ggplot2::geom_sf(data = world, fill = "grey80", color = "grey60", linewidth = 0.2) +
    ggplot2::coord_sf(
      xlim = range(pred_only$lon),
      ylim = range(pred_only$lat),
      expand = TRUE
    ) +
    ggplot2::geom_point(
      data = plot_dat,
      ggplot2::aes(
        x = lon, y = lat,
        size = n_stomachs,
        color = .data[[color]]
      ),
      alpha = 0.7
    ) +
    ggplot2::facet_wrap(facet, ncol = ncol) +
    ggplot2::scale_size_continuous(range = c(0.5, 4)) +
    color_scale +
    ggplot2::labs(x = NULL, y = NULL, color = NULL) +
    ggplot2::theme_light() +
    ggplot2::theme(
      legend.position   = "bottom",
      legend.key.height = ggplot2::unit(0.2, "cm"),
      legend.key.width  = ggplot2::unit(0.8, "cm")
    )
}
