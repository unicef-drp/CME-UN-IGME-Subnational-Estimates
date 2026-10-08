result_specs <- list(
  nmr = list(
    path = file.path(
      "Results", "Afghanistan", "Betabinomial", "NMR",
      "Afghanistan_res_adm1_unstrat_nmr_allsurveys_bench.rda"
    ),
    object = "bb.res.adm1.unstrat.nmr.allsurveys.bench"
  ),
  u5 = list(
    path = file.path(
      "Results", "Afghanistan", "Betabinomial", "U5MR",
      "Afghanistan_res_adm1_unstrat_u5_allsurveys_bench.rda"
    ),
    object = "bb.res.adm1.unstrat.u5.allsurveys.bench"
  )
)

for (outcome in names(result_specs)) {
  spec <- result_specs[[outcome]]
  stopifnot(file.exists(spec$path))

  result_env <- new.env(parent = emptyenv())
  loaded <- load(spec$path, envir = result_env)
  stopifnot(identical(loaded, spec$object))
  result <- result_env[[spec$object]]

  draws <- result$draws.est.overall
  stopifnot(
    inherits(result, "SUMMERprojlist"),
    identical(result$nsim, 1000),
    length(draws) == 34L * 26L,
    length(unique(vapply(draws, `[[`, numeric(1), "years"))) == 26L,
    length(unique(vapply(draws, `[[`, character(1), "region"))) == 34L,
    all(vapply(draws, function(x) {
      length(x$draws) == 1000L && all(is.finite(x$draws))
    }, logical(1)))
  )
}

all_survey_fit <- readLines(file.path(
  "Results", "Afghanistan", "Betabinomial", "NMR",
  "Afghanistan_fit_adm1_unstrat_nmr_allsurveys.txt"
), warn = FALSE)
same_frame_fit <- readLines(file.path(
  "Results", "Afghanistan", "Betabinomial", "NMR",
  "Afghanistan_fit_adm1_strat_nmr_bench.txt"
), warn = FALSE)

stopifnot(
  any(grepl("Survey effect: yes", all_survey_fit, fixed = TRUE)),
  any(grepl("survey.id", all_survey_fit, fixed = TRUE)),
  any(grepl(
    "Survey effect: no, only one survey",
    same_frame_fit,
    fixed = TRUE
  ))
)

cat(
  "Afghanistan final BB8 outputs have 1,000 finite draws for 34 provinces and use a two-survey effect.\n"
)
