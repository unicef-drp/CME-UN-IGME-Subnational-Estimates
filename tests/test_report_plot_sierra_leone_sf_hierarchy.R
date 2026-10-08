script_path <- file.path("Rcode", "11_Report_Plot.R")
comparison_path <- file.path("Rcode", "12_Previous_Final_Comparison.R")
summary_path <- file.path("Rcode", "11_CountrySummary.Rmd")
stopifnot(file.exists(script_path))
stopifnot(file.exists(comparison_path))
stopifnot(file.exists(summary_path))

script <- paste(readLines(script_path, warn = FALSE), collapse = "\n")
comparison_script <- paste(
  readLines(comparison_path, warn = FALSE),
  collapse = "\n"
)
summary_script <- paste(readLines(summary_path, warn = FALSE), collapse = "\n")

stopifnot(
  grepl("poly.adm2[['", script, fixed = TRUE),
  grepl("poly.label.adm1", script, fixed = TRUE),
  !grepl("poly.adm2@data", script, fixed = TRUE),
  grepl("country_print <- gsub", script, fixed = TRUE),
  !grepl("ggtitle(country)", script, fixed = TRUE),
  grepl("country_display <- gsub", comparison_script, fixed = TRUE),
  grepl("country_display, \" \", sub", comparison_script, fixed = TRUE),
  grepl("main = country_print", summary_script, fixed = TRUE),
  !grepl("main = country)", summary_script, fixed = TRUE)
)

cat("Sierra Leone report uses sf hierarchy and human-readable titles.\n")
