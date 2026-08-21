path <- system.file("extdata", package = "stomachr")

# NOTE: deliberately not applying the vignette's `country == "NO"` fix
# (which forces `number` to 1) -- in the bundled example data every pooled
# record happens to be Norwegian, so that fix silently zeroes out all
# pooling and the vignette's own example never exercised
# unpool_predators()'s pooled-row code path. That's exactly how a real bug
# slipped through (a bind_rows() type mismatch when
# tbl_predator_information_id is numeric) -- keeping real pooling here
# means this file doubles as a regression test for it.
dat <- join_stomach_data(path) |> add_taxonomy()

# a pooled fish with a numeric id used to crash unpool_predators() -- check it doesn't anymore
test_that("unpool_predators() works with numeric predator ids (regression test)", {
  # minimal case matching the shape of real ICES data: numeric id, one
  # pooled predator (number = 3) alongside one already-single predator
  toy <- tibble::tibble(
    tbl_predator_information_id = c(1, 1, 2),
    number = c(3, 3, 1),
    count = c(2, 4, 1),
    prey_weight_ind = c(0.5, 0.3, 1),
    weight = c(1, 1.2, 1),
    other_count = c(NA, NA, NA),
    other_wgt = c(NA, NA, NA),
    regurgitated = c(0, 1, 0)
  )

  out <- unpool_predators(toy, method = "uncount")

  expect_s3_class(out, "data.frame")
  expect_true(all(out$number == 1))
  # each (predator, prey item) row is replicated `number` times, not each
  # predator turned into `number` rows total: id 1 has 2 prey-item rows and
  # number = 3, so it expands to 2*3 = 6 rows; id 2 (unpooled) stays as 1
  expect_equal(nrow(out), 7)
  # ...but there are still only 4 *implied individuals* (3 from id 1's
  # pooled group + 1 already-single id 2) -- row count and individual count
  # are different things once a predator can have more than one prey row
  expect_equal(dplyr::n_distinct(out$tbl_predator_information_id), 4)
  expect_type(out$tbl_predator_information_id, "character")
})

# expanding real pooled records should turn every "number > 1" fish into several single fish
test_that("unpool_predators() smoke test on real (partly pooled) data", {
  # sanity check that this fixture is actually pooled, or the test below
  # isn't testing what it claims to
  expect_gt(sum(!is.na(dat$number) & dat$number > 1), 0)

  out <- unpool_predators(dat, method = "uncount")

  expect_s3_class(out, "data.frame")
  expect_true(all(out$number == 1))
  expect_gte(nrow(out), nrow(dat))
})

# the alternative "filter" method should drop pooled fish instead of expanding them
test_that("unpool_predators(method = 'filter') smoke test", {
  out <- unpool_predators(dat, method = "filter")

  expect_s3_class(out, "data.frame")
  expect_true(all(is.na(out$number) | out$number <= 1))
})
