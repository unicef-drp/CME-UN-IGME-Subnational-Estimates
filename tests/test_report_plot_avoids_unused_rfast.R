report_files <- file.path(
  "Rcode",
  c("11_Report_Plot.R", "11_CountrySummary.Rmd")
)

for (script_path in report_files) {
  script_text <- paste(readLines(script_path, warn = FALSE), collapse = "\n")
  if (grepl("(?:library|require)\\s*\\(\\s*Rfast\\s*\\)", script_text,
            perl = TRUE)) {
    stop(
      basename(script_path),
      " should not require Rfast: the report does not use it, ",
      "and its compiled binary can prevent otherwise valid report runs.",
      call. = FALSE
    )
  }
}

cat("Report plot optional-dependency regression test passed.\n")
