# Builds the internal worms_lookup table: AphiaID -> scientific_name, rank,
# phylum, class, order, family, genus.
#
# Queries the WoRMS API for every AphiaID that appears in the full ICES
# stomach content database. Results are cached in data-raw/worms_cache.rds
# so re-runs are instant.
#
# Run once (or after the ICES database is updated):
#   source("data-raw/build_worms_lookup.R")

library(dplyr)
library(worrms)

tmp <- tempfile()
stomachr::download_stomach(path = tmp)

pred <- readr::read_csv(file.path(tmp, "PredatorInformation.csv"), show_col_types = FALSE)
prey <- readr::read_csv(file.path(tmp, "PreyInformation.csv"), show_col_types = FALSE)

all_ids <- unique(c(pred$AphiaIDPredator, prey$AphiaIDPrey)) |>
  stats::na.omit() |>
  as.integer()

cache <- "data-raw/worms_cache.rds"

if (file.exists(cache)) {
  cached <- readRDS(cache)
  missing <- setdiff(all_ids, cached$aphia_id)
} else {
  cached <- NULL
  missing <- all_ids
}

if (length(missing) > 0) {
  cli::cli_inform("Querying WoRMS for {length(missing)} AphiaID{?s}...")
  new_rows <- split(missing, ceiling(seq_along(missing) / 50)) |>
    lapply(\(ids) {
      tryCatch(
        worrms::wm_record(ids) |>
          dplyr::select(AphiaID, scientificname, rank, phylum, class, order, family, genus),
        error = function(e) NULL
      )
    }) |>
    dplyr::bind_rows() |>
    dplyr::rename(aphia_id = AphiaID, scientific_name = scientificname)

  cached <- dplyr::bind_rows(cached, new_rows)
  saveRDS(cached, cache)
}

worms_lookup <- cached

cli::cli_inform(c(
  "v" = "worms_lookup: {nrow(worms_lookup)} records, {sum(is.na(worms_lookup$scientific_name))} unresolved"
))

usethis::use_data(worms_lookup, overwrite = TRUE)
