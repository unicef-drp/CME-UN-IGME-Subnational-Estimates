script_text <- paste(
  readLines(file.path("Rcode", "8_10_BB8.R"), warn = FALSE),
  collapse = "\n"
)

required_patterns <- c(
  'Sys.getenv("BB8_RESUME_ALLSURVEY_BENCHMARKS", "0")',
  "bb8_resume_allsurvey_benchmarks",
  "if (!bb8_resume_allsurvey_admin2_u5 && !bb8_resume_allsurvey_benchmarks)",
  "if(run_admin2_bb8 && !bb8_resume_allsurvey_benchmarks)",
  "bb.res.adm1.unstrat.nmr.allsurveys <- bb8_load_saved_result(",
  "bb.res.adm2.unstrat.nmr.allsurveys <- bb8_load_saved_result(",
  "admin_draws = bb.res.adm2.unstrat.nmr.allsurveys$draws.est.overall",
  "admin_weights = weight.adm2.u1",
  "bb.res.adm1.unstrat.u5.allsurveys <- bb8_load_saved_result(",
  "bb.res.adm2.unstrat.u5.allsurveys <- bb8_load_saved_result(",
  "admin_draws = bb.res.adm2.unstrat.u5.allsurveys$draws.est.overall",
  "admin_weights = weight.adm2.u5"
)

missing_patterns <- required_patterns[
  !vapply(
    required_patterns,
    function(pattern) grepl(pattern, script_text, fixed = TRUE),
    logical(1)
  )
]
if (length(missing_patterns)) {
  stop(
    "All-survey benchmark resume path is incomplete. Missing patterns: ",
    paste(missing_patterns, collapse = ", ")
  )
}

legacy_refits <- c(
  "getSmoothed(inla_mod = bb.adm2.unstrat.nmr.allsurveys$fit",
  "getSmoothed(inla_mod = bb.adm2.unstrat.u5.allsurveys$fit"
)
present_refits <- legacy_refits[
  vapply(
    legacy_refits,
    function(pattern) grepl(pattern, script_text, fixed = TRUE),
    logical(1)
  )
]
if (length(present_refits)) {
  stop(
    "All-survey Admin-2 benchmark preparation still refits/repredicts a ",
    "completed base model: ",
    paste(present_refits, collapse = ", ")
  )
}

cat("All-survey benchmarks resume from saved weighted posterior draws.\n")
