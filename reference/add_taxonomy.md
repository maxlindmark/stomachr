# Add WoRMS taxonomy to predator and prey

Left-joins scientific names and higher taxonomy (class, order, family,
phylum) for both predators and prey using the bundled WoRMS lookup table
([worms_lookup](https://maxlindmark.github.io/stomachr/reference/worms_lookup.md),
built in `data-raw/build_worms_lookup.R`). Prey with
`aphia_id_prey = NA` in non-empty stomachs are labelled `"Unknown"` so
their weight is not silently lost downstream.

## Usage

``` r
add_taxonomy(dat)
```

## Arguments

- dat:

  Tibble from
  [`drop_invalid()`](https://maxlindmark.github.io/stomachr/reference/drop_invalid.md).

## Value

`dat` with added columns `predator_scientific_name`, `predator_class`,
`predator_order`, `predator_family`, `predator_phylum`, and matching
`prey_*` columns.
