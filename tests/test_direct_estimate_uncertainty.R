helper <- file.path(
  "Rcode",
  "_supporting_scripts",
  "direct_estimate_uncertainty.R"
)

env <- new.env(parent = baseenv())
if (file.exists(helper)) {
  sys.source(helper, envir = env)
}

stopifnot(exists(
  "direct_standard_error_bounds",
  envir = env,
  inherits = FALSE
))

direct <- data.frame(
  mean = c(0.5, NA_real_),
  logit.est = c(0, NA_real_),
  var.est = c(0.04, NA_real_)
)
bounds <- env$direct_standard_error_bounds(direct)

stopifnot(
  isTRUE(all.equal(bounds$se_logit[1], 0.2)),
  isTRUE(all.equal(bounds$lower_1se[1], plogis(-0.2))),
  isTRUE(all.equal(bounds$upper_1se[1], plogis(0.2))),
  isTRUE(all.equal(bounds$se_probability[1], 0.05)),
  all(is.na(bounds[2, ]))
)

bad <- try(
  env$direct_standard_error_bounds(
    data.frame(mean = 0.1, logit.est = -2, var.est = -0.1)
  ),
  silent = TRUE
)
stopifnot(
  inherits(bad, "try-error"),
  grepl("non-negative", as.character(bad), fixed = TRUE)
)

report_text <- paste(
  readLines(file.path("Rcode", "11_CountrySummary.Rmd"), warn = FALSE),
  collapse = "\n"
)
stopifnot(
  grepl("direct_estimate_uncertainty.R", report_text, fixed = TRUE),
  grepl("direct_standard_error_bounds(tmp)", report_text, fixed = TRUE),
  grepl("design-based standard error", report_text, fixed = TRUE)
)
