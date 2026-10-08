script_path <- file.path(
  "Data", "Crisis_Adjustment", "apply_cod_crisis_adjustment.R"
)
source(script_path, local = FALSE)

expect_error <- function(expr, pattern) {
  message <- tryCatch(
    {
      force(expr)
      NA_character_
    },
    error = function(e) conditionMessage(e)
  )
  stopifnot(!is.na(message), grepl(pattern, message, ignore.case = TRUE))
}

qx <- crisis_deaths_to_u5mr(
  ed_0_1 = 10,
  ed_1_5 = 20,
  pop_0_1 = 1000,
  pop_1_5 = 4000
)
expected_qx <- 1 -
  (1 - 0.01 / 1.007) *
  (1 - 0.02 / 1.012)
stopifnot(abs(qx - expected_qx) < 1e-12)

expect_error(
  crisis_deaths_to_u5mr(1, 1, 0, 100),
  "positive"
)
expect_error(
  crisis_deaths_to_u5mr(-1, 1, 100, 100),
  "non-negative"
)

summary_table <- data.frame(
  region = c("admin1_1", "admin1_1"),
  time = 1:2,
  area = 1L,
  variance = c(0.01, 0.02),
  median = c(0.20, 0.19),
  mean = c(0.21, 0.20),
  upper = c(0.25, 0.24),
  lower = c(0.15, 0.14),
  years = 2000:2001,
  frame = "frame_all",
  strata_all = 1L,
  is.yearly = FALSE,
  years.num = 2000:2001,
  stringsAsFactors = FALSE
)
stratified_table <- summary_table[, setdiff(names(summary_table), c("frame", "strata_all"))]
stratified_table$strata <- "strata_all"
stratified_table <- stratified_table[c(
  "strata", "time", "area", "variance", "median", "mean",
  "upper", "lower", "years", "region", "is.yearly", "years.num"
)]

model <- list(
  overall = summary_table,
  stratified = stratified_table,
  draws.est.overall = list(
    list(years = 2000L, region = "admin1_1", draws = c(0.18, 0.20, 0.22)),
    list(years = 2001L, region = "admin1_1", draws = c(0.17, 0.19, 0.21))
  ),
  draws.est = list(
    list(
      years = 2000L, region = "admin1_1", strata = "strata_all",
      draws = c(0.18, 0.20, 0.22)
    ),
    list(
      years = 2001L, region = "admin1_1", strata = "strata_all",
      draws = c(0.17, 0.19, 0.21)
    )
  ),
  draws = list(list(marker = 1L))
)

increments <- data.frame(
  region = "admin1_1",
  years = 2000L,
  crisis_5q0 = qx,
  stringsAsFactors = FALSE
)
adjusted <- apply_crisis_increment_to_model(model, increments)
shift_columns <- c("median", "mean", "lower", "upper")

stopifnot(
  all(abs(
    unlist(adjusted$overall[1, shift_columns], use.names = FALSE) -
      unlist(model$overall[1, shift_columns], use.names = FALSE) - qx
  ) < 1e-12),
  identical(adjusted$overall[2, shift_columns], model$overall[2, shift_columns]),
  identical(adjusted$overall$variance, model$overall$variance),
  all(abs(
    unlist(adjusted$stratified[1, shift_columns], use.names = FALSE) -
      unlist(model$stratified[1, shift_columns], use.names = FALSE) - qx
  ) < 1e-12),
  identical(adjusted$stratified[2, shift_columns], model$stratified[2, shift_columns]),
  all(abs(
    adjusted$draws.est.overall[[1]]$draws -
      model$draws.est.overall[[1]]$draws - qx
  ) < 1e-12),
  identical(
    adjusted$draws.est.overall[[2]]$draws,
    model$draws.est.overall[[2]]$draws
  ),
  all(abs(
    adjusted$draws.est[[1]]$draws - model$draws.est[[1]]$draws - qx
  ) < 1e-12),
  identical(adjusted$draws.est[[2]]$draws, model$draws.est[[2]]$draws),
  identical(adjusted$draws, model$draws)
)

expect_error(
  apply_crisis_increment_to_model(model, rbind(increments, increments)),
  "duplicate"
)
expect_error(
  apply_crisis_increment_to_model(
    model,
    transform(increments, region = "admin1_missing")
  ),
  "not present"
)
expect_error(
  apply_crisis_increment_to_model(
    model,
    transform(increments, crisis_5q0 = 0.9)
  ),
  "below one"
)

message("COD crisis application unit tests passed.")

integration <- apply_cod_crisis_adjustment(
  project_root = normalizePath(".", winslash = "/", mustWork = TRUE),
  write_output = FALSE,
  quiet = TRUE
)

source(file.path("Data", "Crisis_Adjustment", "prepare_cod_71_29.R"))
current_source <- read_cod_crisis_source(file.path(
  "Data", "Crisis_Adjustment", "Crisis_Under5_deaths_2026.xlsx"
))
country_info <- jsonlite::fromJSON("Info/DR_Congo_general_info.json")
expected_years <- sort(current_source$years[
  current_source$years >= country_info$beg.year &
    current_source$years <= country_info$end.proj.year
])

level_specs <- list(
  adm1 = list(
    rows = 26L * length(expected_years),
    overall_rows = 26L * 26L,
    input_file = file.path(
      "Results", "DR_Congo", "Betabinomial", "U5MR",
      "DR_Congo_res_adm1_unstrat_u5_allsurveys_bench.rda"
    ),
    object_name = "bb.res.adm1.unstrat.u5.allsurveys.bench"
  ),
  adm2 = list(
    rows = 188L * length(expected_years),
    overall_rows = 188L * 26L,
    input_file = file.path(
      "Results", "DR_Congo", "Betabinomial", "U5MR",
      "DR_Congo_res_adm2_unstrat_u5_allsurveys_bench.rda"
    ),
    object_name = "bb.res.adm2.unstrat.u5.allsurveys.bench"
  )
)

for (level_name in names(level_specs)) {
  specification <- level_specs[[level_name]]
  result <- integration[[level_name]]
  qx_table <- result$crisis_qx
  adjusted_model <- result$model

  stopifnot(
    nrow(qx_table) == specification$rows,
    identical(sort(unique(qx_table$years)), expected_years),
    all(is.finite(qx_table$crisis_5q0)),
    all(qx_table$crisis_5q0 >= 0 & qx_table$crisis_5q0 < 1),
    nrow(adjusted_model$overall) == specification$overall_rows,
    length(adjusted_model$draws.est.overall) == specification$overall_rows,
    length(adjusted_model$draws.est) == specification$overall_rows,
    identical(
      result$report_table,
      adjusted_model$overall[c(
        "region", "years", "time", "area", "median", "upper", "lower",
        "is.yearly"
      )]
    )
  )

  base_environment <- new.env(parent = emptyenv())
  load(specification$input_file, envir = base_environment)
  base_model <- get(
    specification$object_name,
    envir = base_environment,
    inherits = FALSE
  )

  expected_shift <- setNames(
    qx_table$crisis_5q0,
    crisis_region_year_key(qx_table$region, qx_table$years)
  )
  overall_keys <- crisis_region_year_key(
    base_model$overall$region,
    base_model$overall$years
  )
  shift <- unname(expected_shift[overall_keys])
  shift[is.na(shift)] <- 0

  for (column in c("median", "mean", "lower", "upper")) {
    stopifnot(all(abs(
      adjusted_model$overall[[column]] - base_model$overall[[column]] - shift
    ) < 1e-12))
    stopifnot(all(abs(
      adjusted_model$stratified[[column]] -
        base_model$stratified[[column]] - shift
    ) < 1e-12))
    stopifnot(
      all(adjusted_model$overall[[column]] >= 0),
      all(adjusted_model$overall[[column]] < 1),
      all(adjusted_model$stratified[[column]] >= 0),
      all(adjusted_model$stratified[[column]] < 1)
    )
  }
  stopifnot(
    identical(adjusted_model$overall$variance, base_model$overall$variance),
    identical(adjusted_model$stratified$variance, base_model$stratified$variance)
  )

  for (draw_component in c("draws.est.overall", "draws.est")) {
    adjusted_draws <- adjusted_model[[draw_component]]
    base_draws <- base_model[[draw_component]]
    draw_keys <- vapply(
      base_draws,
      function(entry) crisis_region_year_key(entry$region, entry$years),
      character(1)
    )
    draw_shift <- unname(expected_shift[draw_keys])
    draw_shift[is.na(draw_shift)] <- 0
    draw_errors <- vapply(
      seq_along(base_draws),
      function(index) max(abs(
        adjusted_draws[[index]]$draws -
          base_draws[[index]]$draws -
          draw_shift[[index]]
      )),
      numeric(1)
    )
    stopifnot(
      all(draw_errors < 1e-12),
      all(vapply(
        adjusted_draws,
        function(entry) all(entry$draws >= 0 & entry$draws < 1),
        logical(1)
      ))
    )
  }

  rm(base_environment, base_model, adjusted_model, result)
  invisible(gc())
}

message("COD crisis application integration tests passed.")
