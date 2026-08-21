path <- system.file("extdata", package = "stomachr")
dat <- join_stomach_data(path) |>
  add_taxonomy() |>
  unpool_predators() |>
  drop_invalid() |>
  impute_size()

# trimming to analysis-ready columns should keep the useful ones and drop the internal ones
test_that("trim_data() smoke test", {
  out <- trim_data(dat)

  expect_s3_class(out, "data.frame")
  expect_true("predator_scientific_name" %in% names(out))
  expect_false("lw_a" %in% names(out)) # internal L/W column dropped
})
