path <- system.file("extdata", package = "stomachr")
dat <- join_stomach_data(path) |> add_taxonomy()

# adding species names/taxonomy shouldn't leave any non-empty stomach's prey name blank
test_that("add_taxonomy() smoke test", {
  expect_s3_class(dat, "data.frame")
  expect_true(all(c(
    "predator_scientific_name", "predator_class", "prey_scientific_name"
  ) %in% names(dat)))

  # non-empty stomachs with no resolved prey name -- no id recorded at all,
  # OR an id recorded that isn't in worms_lookup -- are labelled "Unknown",
  # never left NA (this used to only cover the "no id at all" half; an id
  # present but missing from worms_lookup silently stayed NA until fixed)
  no_id_not_empty <- is.na(dat$aphia_id_prey) & dat$stomach_status != "empty"
  unmatched_id_not_empty <- !is.na(dat$aphia_id_prey) & is.na(dat$prey_rank) & dat$stomach_status != "empty"
  expect_gt(sum(unmatched_id_not_empty), 0) # sanity: the example data has this case (3 ids not in worms_lookup)
  expect_true(all(dat$prey_scientific_name[no_id_not_empty] == "Unknown"))
  expect_true(all(dat$prey_scientific_name[unmatched_id_not_empty] == "Unknown"))
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
