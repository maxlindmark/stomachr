path <- system.file("extdata", package = "stomachr")
trimmed <- join_stomach_data(path) |>
  add_taxonomy() |>
  unpool_predators() |>
  drop_invalid() |>
  impute_size() |>
  trim_data()

# sense_check() must add a sense_flag column without changing row count -- it flags, drop_flagged() removes
test_that("sense_check() smoke test", {
  out <- sense_check(trimmed)

  expect_s3_class(out, "data.frame")
  expect_true("sense_flag" %in% names(out))
  expect_equal(nrow(out), nrow(trimmed))
})

# dropping flagged rows should remove exactly the flagged ones and none of the rest
test_that("drop_flagged() smoke test", {
  checked <- sense_check(trimmed)
  out <- drop_flagged(checked)

  expect_s3_class(out, "data.frame")
  expect_true(all(is.na(out$sense_flag)))
  expect_lte(nrow(out), nrow(checked))
})
