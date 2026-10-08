qmd <- paste(readLines(file.path("Rcode", "9_Comparison_Plot.qmd"),
                       warn = FALSE), collapse = "\n")

required <- c(
  "if (!isTRUE(bundle$has_admin2))",
  "#admin-2-all-available-methods",
  "#toc-admin-2-all-available-methods"
)

missing <- required[!vapply(required, grepl, logical(1), x = qmd,
                            fixed = TRUE)]
if (length(missing) > 0) {
  stop("Admin1-only dashboards do not hide the generic Admin2 section: ",
       paste(missing, collapse = ", "))
}

raw_html_setup <-
  grepl("```{r setup, results='asis'}", qmd, fixed = TRUE) ||
  grepl('```{r setup, results="asis"}', qmd, fixed = TRUE)
if (!raw_html_setup) {
  stop(paste(
    "Conditional Admin2 CSS must be emitted as raw HTML.",
    "Otherwise the <style> block appears as escaped code below the dashboard title."
  ))
}

cat(paste(
  "Admin1-only dashboards hide the Admin2 section and TOC entry",
  "without displaying the conditional CSS as code.\n"
))
