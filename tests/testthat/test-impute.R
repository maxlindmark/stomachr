path <- system.file("extdata", package = "stomachr")
dat <- join_stomach_data(path) |>
  add_taxonomy() |>
  unpool_predators() |>
  drop_invalid()

# filling in missing weights/lengths shouldn't add or remove any rows
test_that("impute_size() smoke test", {
  out <- impute_size(dat)

  expect_s3_class(out, "data.frame")
  expect_true(all(c(
    "predator_weight", "predator_weight_estimated", "prey_lw_source"
  ) %in% names(out)))
  expect_equal(nrow(out), nrow(dat))
})
