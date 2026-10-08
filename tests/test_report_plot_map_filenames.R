script <- paste(readLines(file.path("Rcode", "11_Report_Plot.R"),
                          warn = FALSE),
                collapse = "\n")

bad_pattern <- 'min(selected_years)), max(selected_years), ".pdf"'
if (grepl(bad_pattern, script, fixed = TRUE)) {
  stop("Selected-year map filenames should keep min/max years in the filename, not as path components.")
}

required_pattern <- 'min(selected_years), "_", max(selected_years), ".pdf")'
stopifnot(grepl(required_pattern, script, fixed = TRUE))

cat("Report plot selected-year map filenames keep year ranges in the basename.\n")
