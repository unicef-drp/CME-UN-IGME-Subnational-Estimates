script_text <- paste(readLines("Rcode/9_Diagnostic_Plots.R", warn = FALSE), collapse = "\n")

expected_models <- c(
  "adm2_unstrat_nmr_allsurveys_bench",
  "adm2_unstrat_u5_allsurveys_bench",
  "adm1_strat_nmr_bench",
  "adm2_strat_nmr_bench",
  "adm1_strat_u5_bench",
  "adm2_strat_u5_bench"
)

for (model in expected_models) {
  stopifnot(grepl(model, script_text, fixed = TRUE))
}

cat("Diagnostic model candidates include benchmarked Admin1/Admin2 models.\n")
