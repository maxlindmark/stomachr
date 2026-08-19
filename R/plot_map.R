#' Plot sampling locations on a map
#'
#' Plots haul locations as points on a map of the North Sea.
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
#' @param xlim,ylim Optional length-2 numeric vectors overriding the
#'   automatic (data range + padding) map extent.
#'
#' @return A `ggplot` object.
#' @export
plot_map <- function(dat,
                     color = "predator_scientific_name",
                     facet = "predator_scientific_name",
                     species = NULL,
                     ncol = 4,
                     xlim = NULL,
                     ylim = NULL) {
  pred_only <- dat |>
    dplyr::distinct(tbl_predator_information_id, .keep_all = TRUE) |>
    dplyr::filter(!is.na(lat), !is.na(lon))

  # The top-species filter only makes sense (and only needs
  # predator_scientific_name to exist) when species is actually what's being
  # plotted; skip it entirely when coloring/faceting by something else, e.g.
  # year or country.
  if ("predator_scientific_name" %in% c(color, facet)) {
    if (is.null(species)) {
      species <- pred_only |>
        dplyr::count(predator_scientific_name, sort = TRUE) |>
        dplyr::slice_head(n = 8) |>
        dplyr::pull(predator_scientific_name)
    }
    pred_only <- dplyr::filter(pred_only, predator_scientific_name %in% species)
  }

  group_cols <- unique(c("lon", "lat", color, facet))
  plot_dat <- pred_only |>
    dplyr::count(dplyr::across(dplyr::all_of(group_cols)), name = "n_stomachs")

  color_scale <- if (is.numeric(plot_dat[[color]])) {
    ggplot2::scale_color_viridis_c()
  } else {
    # override.aes enlarges just the legend swatches (independent of the
    # actual n_stomachs-driven point sizes on the map) so colors are still
    # easy to tell apart at a glance. Dark2 tops out at 8 colors -- fine for
    # the default top-8-species case, but a discrete color/facet variable
    # with more than 8 levels will get some NA (grey) points.
    ggplot2::scale_color_brewer(
      palette = "Dark2",
      guide = ggplot2::guide_legend(override.aes = list(size = 3))
    )
  }

  world <- ggplot2::map_data("world")

  # Pad the bounding box beyond the exact data range so tightly clustered
  # points (e.g. a handful of hauls near one island) still show surrounding
  # coastline for context, instead of being cropped right at the data edge.
  # Capped at 2 degrees so this stays a small nudge for already-wide ranges
  # (e.g. the Baltic Sea) rather than compounding into a lot of extra
  # whitespace; pass xlim/ylim explicitly to override the padding entirely.
  lon_range <- range(pred_only$lon)
  lat_range <- range(pred_only$lat)
  lon_pad <- pmin(pmax(diff(lon_range) * 0.15, 1), 2)
  lat_pad <- pmin(pmax(diff(lat_range) * 0.15, 1), 2)

  if (is.null(xlim)) xlim <- lon_range + c(-lon_pad, lon_pad)
  if (is.null(ylim)) ylim <- lat_range + c(-lat_pad, lat_pad)

  ggplot2::ggplot() +
    ggplot2::geom_polygon(
      data = world,
      ggplot2::aes(x = .data[["long"]], y = .data[["lat"]], group = .data[["group"]]),
      fill = "grey80", colour = "grey60", linewidth = 0.2
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
    ggplot2::coord_quickmap(
      xlim = xlim,
      ylim = ylim,
      expand = TRUE
    ) +
    ggplot2::facet_wrap(facet, ncol = ncol) +
    ggplot2::scale_size_continuous(range = c(0.5, 4)) +
    color_scale +
    ggplot2::labs(x = NULL, y = NULL, color = NULL) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      legend.position   = "bottom",
      legend.key.height = ggplot2::unit(0.35, "cm"),
      legend.key.width  = ggplot2::unit(0.8, "cm")
    )
}
