# Trim to analysis-ready columns

Drops the internal processing columns that are no longer needed after
the cleaning pipeline, keeping only the columns listed below.

## Usage

``` r
trim_data(dat)
```

## Arguments

- dat:

  Tibble from
  [`impute_size()`](https://maxlindmark.github.io/stomachr/reference/impute_size.md).

## Value

A tibble with columns: `tbl_upload_id`, `tbl_haul_id`,
`tbl_predator_information_id`, `country`, `survey`, `year`, `month`,
`day`, `time`, `lat`, `lon`, `ices_rectangle`, `depth`,
`stomach_status`, `regurgitated`, `aphia_id_predator`,
`predator_scientific_name`, `predator_class`, `predator_order`,
`predator_family`, `pred_length`, `predator_weight`,
`predator_weight_estimated`, `age`, `sex`, `tbl_prey_information_id`,
`aphia_id_prey`, `prey_scientific_name`, `prey_class`, `prey_order`,
`prey_family`, `digestion_stage`, `sub_factor`, `count`,
`count_censored`, `prey_length`, `prey_weight_ind`,
`prey_weight_all_ind`, `other_wgt`, `prey_lw_source`, `lw_source`,
`pred_lw_source`, `analysing_org`.
