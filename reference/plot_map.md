# Plot sampling locations on a map

Plots haul locations as points on a Lambert Conformal Conic projection
centred on the North Sea.

## Usage

``` r
plot_map(
  dat,
  color = "predator_scientific_name",
  facet = "predator_scientific_name",
  species = NULL,
  ncol = 4
)
```

## Arguments

- dat:

  Tibble from
  [`trim_data()`](https://maxlindmark.github.io/stomachr/reference/trim_data.md)
  or later. Must contain columns `lat`, `lon`, and
  `tbl_predator_information_id`.

- color:

  Column name (as a string) to colour points by. Defaults to
  `"predator_scientific_name"`.

- facet:

  Column name (as a string) to facet by. Defaults to
  `"predator_scientific_name"`.

- species:

  Character vector of species to include (filters on
  `predator_scientific_name`). Defaults to the top 8 predators by number
  of stomachs.

- ncol:

  Number of columns in `facet_wrap`.

## Value

A `ggplot` object.

## Details

Requires the rnaturalearth package for the background land layer.
