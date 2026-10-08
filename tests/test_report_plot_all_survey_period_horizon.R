script_text <- paste(readLines(file.path("Rcode", "11_Report_Plot.R"),
                               warn = FALSE),
                     collapse = "\n")

required_fragments <- c(
  'all_survey_file <- file.path(data.dir, paste0(country, "_cluster_dat.rda"))',
  'load(all_survey_file, envir = all_survey_env)',
  'end.year <- max(all_survey_env$mod.dat$survey)'
)

missing <- required_fragments[!vapply(required_fragments, grepl, logical(1),
                                      x = script_text, fixed = TRUE)]
if (length(missing) > 0) {
  stop("Report plot should derive direct-estimate periods from the all-survey horizon. Missing: ",
       paste(missing, collapse = ", "))
}

cat("Report plot direct periods use the all-survey horizon.\n")
