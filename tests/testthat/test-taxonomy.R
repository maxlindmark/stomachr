path <- system.file("extdata", package = "stomachr")
dat <- join_stomach_data(path) |> add_taxonomy()

# adding species names/taxonomy shouldn't leave any non-empty stomach's prey name blank
test_that("add_taxonomy() smoke test", {
  expect_s3_class(dat, "data.frame")
  expect_true(all(c(
    "predator_scientific_name", "predator_class", "prey_scientific_name"
  ) %in% names(dat)))

  # non-empty stomachs with no resolved prey id are labelled "Unknown", never left NA
  no_id_not_empty <- is.na(dat$aphia_id_prey) & dat$stomach_status != "empty"
  expect_true(all(dat$prey_scientific_name[no_id_not_empty] == "Unknown"))
})

# an id can be present but still missing from worms_lookup (a stale/incomplete
# cache), which used to leave prey_scientific_name silently NA instead of
# "Unknown". Uses a fabricated id rather than relying on the bundled example
# data happening to have a real gap -- that gap closes whenever worms_lookup
# gets refreshed, which would make a real-data version of this test flaky.
test_that("add_taxonomy() labels a present-but-unmatched id as Unknown", {
  toy <- tibble::tibble(
    aphia_id_predator = NA_real_,
    aphia_id_prey = -999999, # not a real AphiaID
    stomach_status = "food"
  )

  out <- add_taxonomy(toy)

  expect_equal(out$prey_scientific_name, "Unknown")
})

# a prey identified only to a rank coarser than family (e.g. "Polychaeta", a
# class) has a real, resolved name but a genuinely NA prey_family -- distinct
# from "Unknown" above, which is for prey with no resolved name at all.
# prey_rank being non-NA is what marks a genuine match here (a true
# non-match leaves every prey_* column NA, including prey_rank).
test_that("add_taxonomy() leaves prey_family NA for coarser-than-family ids, without touching the name", {
  coarser_than_family <- !is.na(dat$aphia_id_prey) & !is.na(dat$prey_rank) & is.na(dat$prey_family)

  expect_gt(sum(coarser_than_family), 0) # sanity: the example data actually has this case
  expect_true(all(dat$prey_scientific_name[coarser_than_family] != "Unknown"))
  expect_true(all(!is.na(dat$prey_scientific_name[coarser_than_family])))
})
