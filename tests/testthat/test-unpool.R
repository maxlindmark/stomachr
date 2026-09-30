path <- system.file("extdata", package = "stomachr")
dat <- join_example(path) |> add_taxonomy() |> drop_invalid()

test_that("unpool_predators() requires drop_invalid() first", {
  toy <- tibble::tibble(tbl_predator_information_id = 1, number = 3)
  expect_error(unpool_predators(toy), "drop_invalid")
})

test_that("unpool_predators() works with numeric predator ids (regression test)", {
  toy <- tibble::tibble(
    tbl_predator_information_id = c(1, 1, 2),
    number = c(3, 3, 1),
    n_stomachs = c(3, 3, 1),
    n_empty = c(0, 0, 0),
    stomach_status = "food",
    count = c(2L, 4L, 1L),
    prey_weight_ind = c(0.5, 0.3, 1),
    weight = c(1, 1.2, 1),
    other_count = NA_integer_,
    other_wgt = NA_real_,
    regurgitated = c(0, 0, 0)
  )

  out <- unpool_predators(toy)

  expect_equal(nrow(out), 7)
  expect_equal(dplyr::n_distinct(out$tbl_predator_information_id), 4)
  expect_type(out$tbl_predator_information_id, "character")
  expect_true(all(out$n_stomachs == 1))
})

test_that("unpool_predators() splits prey over fed copies and adds empty copies", {
  toy <- tibble::tibble(
    tbl_predator_information_id = c(1, 1),
    number = 10,
    n_stomachs = 10,
    n_empty = 3,
    stomach_status = "food",
    aphia_id_prey = c(101, 102),
    count = c(7L, 14L),
    prey_weight_ind = c(1, 0.5),
    weight = c(7, 7),
    other_count = NA_integer_,
    other_wgt = NA_real_,
    regurgitated = 0
  )

  out <- unpool_predators(toy)

  expect_equal(dplyr::n_distinct(out$tbl_predator_information_id), 10)

  empty_rows <- dplyr::filter(out, stomach_status == "empty")
  expect_equal(nrow(empty_rows), 3)
  expect_true(all(is.na(empty_rows$aphia_id_prey)))

  fed_rows <- dplyr::filter(out, stomach_status == "food")
  expect_equal(dplyr::n_distinct(fed_rows$tbl_predator_information_id), 7)
  expect_equal(sum(fed_rows$count[fed_rows$aphia_id_prey == 101]), 7)
  expect_equal(sum(fed_rows$weight), 14)
  expect_equal(sort(fed_rows$count[fed_rows$aphia_id_prey == 101]), c(1, 1, 1, 1, 1, 1, 1))
})

test_that("regurgitated fish get no share of a pool's prey", {
  toy <- tibble::tibble(
    tbl_predator_information_id = 1,
    country = "NL",
    number = 10,
    regurgitated = 3,
    stomach_empty = 0,
    stomach_status = "food",
    count = 7L,
    prey_weight_ind = 1,
    weight = 7,
    other_count = NA_integer_,
    other_wgt = NA_real_
  )

  out <- suppressMessages(drop_invalid(toy)) |> unpool_predators()

  expect_equal(nrow(out), 7)
  expect_equal(sum(out$weight), 7)
  expect_true(all(out$count == 1))
  expect_true(all(out$regurgitated == 0))
})

test_that("unpool_predators() smoke test on real (partly pooled) data", {
  expect_gt(sum(dat$n_stomachs > 1), 0)

  out <- unpool_predators(dat)

  expect_true(all(out$n_stomachs == 1))
  expect_equal(
    dplyr::n_distinct(out$tbl_predator_information_id),
    sum(dplyr::distinct(dat, tbl_predator_information_id, n_stomachs)$n_stomachs)
  )
})
