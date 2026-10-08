script_path <- file.path("Rcode", "8_10_BB8.R")
script_text <- paste(readLines(script_path, warn = FALSE), collapse = "\n")

required_patterns <- c(
  "admin_draws = bb.res.adm2.strat.nmr$draws.est.overall",
  "admin_weights = weight.adm2.u1",
  "admin_draws = bb.res.adm2.strat.u5$draws.est.overall",
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
    "Admin-2 stratified benchmarks do not use saved population-weighted ",
    "posterior draws. Missing patterns: ",
    paste(missing_patterns, collapse = ", ")
  )
}

legacy_refits <- c(
  "getSmoothed(inla_mod = bb.adm2.strat.nmr$fit",
  "getSmoothed(inla_mod = bb.adm2.strat.u5$fit"
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
    "Admin-2 stratified benchmark preparation still refits/repredicts the ",
    "completed base model: ",
    paste(present_refits, collapse = ", ")
  )
}

cat("Admin-2 stratified benchmarks reuse saved weighted posterior draws.\n")
