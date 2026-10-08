qmd_text <- paste(readLines("Rcode/9_Comparison_Plot.qmd", warn = FALSE), collapse = "\n")

required_fragments <- c(
  "method_admin_level = classify_method_admin_level(method)",
  "all_methods_admin1",
  "all_methods_admin2",
  "## Admin 1 All Available Methods",
  "## Admin 2 All Available Methods",
  "all-methods-admin1-u5mr",
  "all-methods-admin1-nmr",
  "all-methods-admin2-u5mr",
  "all-methods-admin2-nmr",
  "available-method-table"
)

missing <- required_fragments[!vapply(required_fragments, grepl, logical(1),
                                      x = qmd_text, fixed = TRUE)]
if (length(missing) > 0) {
  stop("Dashboard should split all available methods by admin level. Missing: ",
       paste(missing, collapse = ", "))
}

if (grepl("all-method-table-admin1", qmd_text, fixed = TRUE) ||
    grepl("all-method-table-admin2", qmd_text, fixed = TRUE)) {
  stop("Dashboard should use one combined method table instead of per-admin method tables.")
}

cat("Dashboard all-method views are split by Admin1 and Admin2 with one combined method table.\n")
