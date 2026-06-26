# Length-weight parameters

L/W parameters for prey and predator species, with taxonomic fallback
rows at family, order, class, and phylum level. Built by
`data-raw/build_lw_params.R`.

## Usage

``` r
lw_params
```

## Format

A tibble with columns:

- aphia_id:

  WoRMS AphiaID (species-level rows only)

- family, order, class, phylum:

  Taxonomic group (fallback rows)

- lw_a:

  Coefficient \\a\\ in \\W = a \cdot L^b\\

- lw_b:

  Exponent \\b\\

- lw_source:

  One of `"species"`, `"family"`, `"order"`, `"class"`, `"phylum"`

## Details

Formula: \\W_g = a \cdot L\_{cm}^b\\

Sources:

- Fish (Chordata): FishBase via
  [`rfishbase::length_weight()`](https://docs.ropensci.org/rfishbase/reference/length_weight.html),
  averaged across parameter sets on the log10 scale.

- Invertebrates: Robinson et al. (2010), originally in mm, rescaled to
  cm.

## References

Robinson, R.A. et al. (2010). Trophic relationships of marine benthic
invertebrates in the North Sea. *Journal of the Marine Biological
Association of the United Kingdom*, 90(7), 1375-1388.
