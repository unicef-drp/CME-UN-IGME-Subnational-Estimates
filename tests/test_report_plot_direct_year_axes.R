script <- readLines(file.path("Rcode", "11_Report_Plot.R"), warn = FALSE)

bad_patterns <- c(
  "lines(2000:end.year, tmp$median",
  "points(2000:end.year, tmp$median"
)

bad_hits <- bad_patterns[vapply(bad_patterns, function(pattern) {
  any(grepl(pattern, script, fixed = TRUE))
}, logical(1))]

if (length(bad_hits) > 0) {
  stop("Direct survey plots should use tmp$years, not a fixed 2000:end.year axis:\n",
       paste(bad_hits, collapse = "\n"))
}

cat("Report plot direct survey layers use observed years for x axes.\n")
