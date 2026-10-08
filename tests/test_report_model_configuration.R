report_plot <- paste(readLines(file.path("Rcode", "11_Report_Plot.R"),
                               warn = FALSE),
                     collapse = "\n")
country_summary <- paste(readLines(file.path("Rcode", "11_CountrySummary.Rmd"),
                                   warn = FALSE),
                         collapse = "\n")

for (script_text in list(report_plot, country_summary)) {
  if (!grepl("require_country_context()", script_text, fixed = TRUE)) {
    stop("Report scripts should use the country context loaded by 1_Preperation.R.")
  }
  if (!grepl("final_model$", script_text, fixed = TRUE)) {
    stop("Report scripts should read final model choices from the loaded country context.")
  }
}

forbidden_literals <- c(
  "country <- \"Laos\"",
  "load(file = file.path(home.dir, \"Info\", info.name))",
  "time.model <- c('ar1','rw2')[1]",
  "time.model <- c('ar1', 'rw2')[1]",
  'strata.model <- c("strat", "unstrat")[2]',
  'bench.model <- c("", "bench")[2]'
)

for (literal in forbidden_literals) {
  if (grepl(literal, report_plot, fixed = TRUE) ||
      grepl(literal, country_summary, fixed = TRUE)) {
    stop("Report scripts should not hard-code final model config: ", literal)
  }
}

cat("Report scripts read final model choices from the prepared country context.\n")
