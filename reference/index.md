# Package index

## Download

- [`download_stomach()`](https://maxlindmark.github.io/stomachr/reference/download_stomach.md)
  : Download ICES stomach content data

## Cleaning pipeline

- [`join_stomach_data()`](https://maxlindmark.github.io/stomachr/reference/join_stomach_data.md)
  : Read and join the four ICES stomach content CSVs
- [`add_taxonomy()`](https://maxlindmark.github.io/stomachr/reference/add_taxonomy.md)
  : Add WoRMS taxonomy to predator and prey
- [`unpool_predators()`](https://maxlindmark.github.io/stomachr/reference/unpool_predators.md)
  : Resolve pooled predator records to one row per predator
- [`drop_invalid()`](https://maxlindmark.github.io/stomachr/reference/drop_invalid.md)
  : Drop invalid (regurgitated) predator records
- [`impute_size()`](https://maxlindmark.github.io/stomachr/reference/impute_size.md)
  : Impute missing prey and predator sizes
- [`trim_data()`](https://maxlindmark.github.io/stomachr/reference/trim_data.md)
  : Trim to analysis-ready columns
- [`sense_check()`](https://maxlindmark.github.io/stomachr/reference/sense_check.md)
  : Flag implausible records
- [`drop_flagged()`](https://maxlindmark.github.io/stomachr/reference/drop_flagged.md)
  : Remove flagged records

## Visualisation

- [`plot_map()`](https://maxlindmark.github.io/stomachr/reference/plot_map.md)
  : Plot sampling locations on a map

## Bundled data

- [`worms_lookup`](https://maxlindmark.github.io/stomachr/reference/worms_lookup.md)
  : WoRMS taxonomic lookup table
- [`lw_params`](https://maxlindmark.github.io/stomachr/reference/lw_params.md)
  : Length-weight parameters
