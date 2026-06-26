# Builds the internal lw_params table: L/W parameters for prey/predator
# species and taxonomic fallback levels (family -> order -> class -> phylum).
#
# Formula: W_g = lw_a * L_cm^lw_b
#
# Sources:
#   Invertebrates: Robinson et al. 2010 (parameters originally in mm, rescaled to cm)
#   Fish (Chordata): rfishbase::length_weight()
#
# Requires:
#   - build_worms_lookup.R to have been run first (worms_lookup in R/sysdata.rda)
#   - data-raw/length-weight-Robinson_2010.csv  (columns: species, a, b)
#
# Run after build_worms_lookup.R:
#   source("data-raw/build_lw_params.R")

library(dplyr)

# Load worms_lookup built by build_worms_lookup.R
load("data/worms_lookup.rda")

# --- Robinson 2010 (invertebrates) ------------------------------------------
robinson_path <- "data-raw/length-weight-Robinson_2010.csv"
if (!file.exists(robinson_path)) {
  cli::cli_abort(c(
    "Missing: {.path {robinson_path}}",
    "i" = "Add the Robinson et al. 2010 L/W parameter CSV to data-raw/ and re-run."
  ))
}

robinson_raw <- readr::read_csv(robinson_path, show_col_types = FALSE) |>
  janitor::clean_names()

aphia_cache <- "data-raw/robinson_aphia.rds"

if (!file.exists(aphia_cache)) {
  cli::cli_inform("Looking up AphiaIDs for {nrow(robinson_raw)} Robinson species...")
  aphia_df <- purrr::map(
    robinson_raw$species,
    \(sp) {
      id <- tryCatch(worrms::wm_name2id(sp), error = function(e) NA_integer_)
      Sys.sleep(0.3)
      tibble::tibble(species = sp, aphia_id = as.integer(id))
    }
  ) |>
    purrr::list_rbind()
  saveRDS(aphia_df, aphia_cache)
} else {
  aphia_df <- readRDS(aphia_cache)
}

robinson <- robinson_raw |>
  left_join(aphia_df, by = "species") |>
  mutate(
    # log10(W_g) = a + b*log10(L_mm), rescaled to L_cm: lw_a = 10^a * 10^b
    lw_a = 10^a * 10^b,
    lw_b = b
  ) |>
  filter(!is.na(aphia_id)) |>
  select(aphia_id, lw_a, lw_b) |>
  left_join(
    worms_lookup |> select(aphia_id, family, order, class, phylum),
    by = "aphia_id"
  ) |>
  select(aphia_id, family, order, class, phylum, lw_a, lw_b)

robinson <- robinson |>
  mutate(
    lw_b = if_else(lw_a > 2, 3, lw_b),
    lw_a = if_else(lw_a > 2, 0.01, lw_a)
  )

# --- FishBase (Chordata) ----------------------------------------------------
fish_names <- worms_lookup |>
  filter(phylum == "Chordata") |>
  pull(scientific_name) |>
  unique()

fishbase_cache <- "data-raw/fishbase_lw.rds"

if (!file.exists(fishbase_cache)) {
  cli::cli_inform("Querying FishBase for {length(fish_names)} Chordata species...")
  fishbase_raw <- rfishbase::length_weight(fish_names)
  saveRDS(fishbase_raw, fishbase_cache)
} else {
  fishbase_raw <- readRDS(fishbase_cache)
}

fishbase <- fishbase_raw |>
  filter(!is.na(a), !is.na(b), a > 0) |>
  summarise(
    lw_a = 10^mean(log10(a), na.rm = TRUE),
    lw_b = mean(b, na.rm = TRUE),
    .by  = Species
  ) |>
  rename(scientific_name = Species) |>
  left_join(
    worms_lookup |> select(scientific_name, aphia_id, family, order, class, phylum),
    by = "scientific_name"
  ) |>
  filter(!is.na(aphia_id)) |>
  select(aphia_id, family, order, class, phylum, lw_a, lw_b)

# --- Combine and build fallback rows ----------------------------------------
all_sp <- bind_rows(robinson, fishbase) |>
  summarise(
    lw_a   = 10^mean(log10(lw_a)),
    lw_b   = mean(lw_b),
    family = first(family),
    order  = first(order),
    class  = first(class),
    phylum = first(phylum),
    .by    = aphia_id
  )

make_fallback <- function(data, group_col, label) {
  data |>
    filter(!is.na(.data[[group_col]])) |>
    summarise(lw_a = 10^mean(log10(lw_a)), lw_b = mean(lw_b), .by = all_of(group_col)) |>
    mutate(lw_source = label)
}

lw_params <- bind_rows(
  all_sp |> mutate(lw_source = "species"),
  make_fallback(all_sp, "family", "family"),
  make_fallback(all_sp, "order", "order"),
  make_fallback(all_sp, "class", "class"),
  make_fallback(all_sp, "phylum", "phylum")
)

cli::cli_inform(c(
  "v" = "lw_params built",
  "i" = "{sum(lw_params$lw_source == 'species')} species-level rows",
  "i" = "{sum(lw_params$lw_source == 'family')} family-level rows",
  "i" = "{sum(lw_params$lw_source == 'order')} order-level rows",
  "i" = "{sum(lw_params$lw_source == 'class')} class-level rows",
  "i" = "{sum(lw_params$lw_source == 'phylum')} phylum-level rows"
))

usethis::use_data(lw_params, overwrite = TRUE)
