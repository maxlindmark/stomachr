# WoRMS taxonomic lookup table

Scientific names and higher taxonomy for every AphiaID that appears in
the full ICES stomach content database. Built by
`data-raw/build_worms_lookup.R` via the WoRMS API
([`worrms::wm_record()`](https://docs.ropensci.org/worrms/reference/wm_record.html)).

## Usage

``` r
worms_lookup
```

## Format

A tibble with columns:

- aphia_id:

  WoRMS AphiaID (integer)

- scientific_name:

  Scientific name

- rank:

  Taxonomic rank (e.g. `"Species"`, `"Genus"`)

- phylum:

  Phylum

- class:

  Class

- order:

  Order

- family:

  Family

- genus:

  Genus
