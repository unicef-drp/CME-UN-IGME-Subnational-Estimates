report_path <- file.path("Rcode", "11_CountrySummary.Rmd")
stopifnot(file.exists(report_path))

report_text <- paste(readLines(report_path, warn = FALSE), collapse = "\n")

required_snippets <- c(
  "survey_tables_per_page <- 5L",
  "survey_table_pages <- split(",
  "seq_along(sum.tableList)",
  "cat(\"\\\\clearpage\\n\")"
)

missing_snippets <- required_snippets[
  !vapply(required_snippets, grepl, logical(1), x = report_text,
          fixed = TRUE)
]

if (length(missing_snippets) > 0L) {
  stop(
    "Country summary must paginate the per-survey age-group tables. ",
    "Missing: ", paste(missing_snippets, collapse = ", "),
    call. = FALSE
  )
}

cat("Country summary paginates survey age-group tables.\n")
