rmd_text <- paste(readLines(file.path("Rcode", "11_CountrySummary.Rmd"),
                            warn = FALSE),
                  collapse = "\n")

required_fragments <- c(
  "selected_natl_result <- function(outcome)",
  "selected_natl_panel_result <- function(metric_dir, outcome, weights)",
  'if (bench.model != "")',
  'paste0("adm1_strat_", outcome, "_bench")',
  'paste0("adm1_unstrat_", outcome, "_allsurveys_bench")',
  "aggregate_admin1_draws(",
  "natl_strat_",
  "natl_unstrat_",
  'nmr.original <- selected_natl_panel_result("NMR", "nmr", weight.adm1.u1)',
  'u5.original <- selected_natl_panel_result("U5MR", "u5", weight.adm1.u5)',
  "bb_result_exists(\"NMR\", \"adm1_unstrat_nmr_allsurveys\")",
  'Sys.getenv("BB8_ADMIN1_ONLY", "0")',
  'run_admin2_summary <- exists("poly.layer.adm2", inherits = TRUE)',
  "if(run_admin2_summary){"
)

missing <- required_fragments[!vapply(required_fragments, grepl, logical(1),
                                      x = rmd_text, fixed = TRUE)]
if (length(missing) > 0) {
  stop("Country summary national plots should load the selected final model. Missing: ",
       paste(missing, collapse = ", "))
}

if (grepl("nmr.original <- bb_overall(", rmd_text, fixed = TRUE) ||
    grepl("u5.original <- bb_overall(", rmd_text, fixed = TRUE)) {
  stop("The selected left panel must not always load an unbenchmarked national model.")
}

cat("Country summary national comparison follows final_model.\n")
