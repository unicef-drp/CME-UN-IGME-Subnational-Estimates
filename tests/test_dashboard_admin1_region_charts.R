qmd_text <- paste(readLines(file.path("Rcode", "9_Comparison_Plot.qmd"),
                            warn = FALSE),
                  collapse = "\n")

required_fragments <- c(
  "build_admin1_model_estimates <- function(bundle)",
  "make_admin1_region_tabs <- function(data, outcome_name = \"U5MR\")",
  "Admin 1 U5MR by region",
  "admin1-region-tabs",
  "admin1-region-tab-content",
  "Stratified vs unstratified - benchmarked",
  "Stratified vs unstratified - unbenchmarked",
  "split by benchmark status",
  "All-survey unstratified BB8",
  "Same-frame stratified BB8",
  "load_admin1_lookup <- function(bundle)"
)

missing <- required_fragments[!vapply(required_fragments, grepl, logical(1),
                                      x = qmd_text, fixed = TRUE)]
if (length(missing) > 0) {
  stop("Dashboard is missing Admin-1 region chart recovery pieces: ",
       paste(missing, collapse = ", "))
}

cat("Dashboard template includes recovered Admin-1 region tab charts.\n")
