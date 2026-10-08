helper_path <- file.path(
  "Rcode", "_supporting_scripts", "report_output_config.R"
)
if (!file.exists(helper_path)) {
  stop("Missing reusable report-output configuration helper: ", helper_path)
}
source(helper_path)

full_snnp_name <-
  "Southern Nations, Nationalities, and Peoples\u2019 Region"
name_map <- c(Snnp = full_snnp_name)

stopifnot(identical(
  apply_report_admin_name_map(c("Snnp", "Oromia"), name_map),
  c(full_snnp_name, "Oromia")
))
stopifnot(identical(
  apply_report_admin_name_map(c("Snnp", NA_character_), NULL),
  c("Snnp", NA_character_)
))
stopifnot(inherits(
  try(
    apply_report_admin_name_map(
      "Snnp",
      c(Snnp = "First", Snnp = "Second")
    ),
    silent = TRUE
  ),
  "try-error"
))
stopifnot(inherits(
  try(
    apply_report_admin_name_map("Snnp", c(Snnp = "")),
    silent = TRUE
  ),
  "try-error"
))

layout <- report_selected_map_layout()
stopifnot(identical(layout$nrow, 2L))
stopifnot(identical(layout$ncol, 3L))
stopifnot(identical(layout$width, 10.5))
stopifnot(identical(layout$height, 7))

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required for this regression test.")
}
ethiopia_info <- jsonlite::fromJSON(
  file.path("Info", "Ethiopia_general_info.json"),
  simplifyVector = TRUE
)
stopifnot(identical(
  unname(ethiopia_info$report_admin_name_map[["Snnp"]]),
  full_snnp_name
))

report_text <- paste(
  readLines(file.path("Rcode", "11_Report_Plot.R"), warn = FALSE),
  collapse = "\n"
)
required_report_fragments <- c(
  'source("Rcode/_supporting_scripts/report_output_config.R")',
  "admin1.names$Join <- admin1.names$Display",
  "admin1.names$Display <- apply_report_admin_name_map(",
  "selected_map_layout <- report_selected_map_layout()"
)
missing_report_fragments <- required_report_fragments[!vapply(
  required_report_fragments,
  grepl,
  logical(1),
  x = report_text,
  fixed = TRUE
)]
if (length(missing_report_fragments) > 0L) {
  stop(
    "Report plot is missing configured output behavior: ",
    paste(missing_report_fragments, collapse = ", ")
  )
}

count_fixed <- function(pattern, text) {
  matches <- gregexpr(pattern, text, fixed = TRUE)[[1]]
  if (identical(matches, -1L)) 0L else length(matches)
}
if (count_fixed("ncol = selected_map_layout$ncol", report_text) < 2L ||
    count_fixed("width = selected_map_layout$width", report_text) < 2L ||
    count_fixed("height = selected_map_layout$height", report_text) < 2L) {
  stop("Admin-1 and Admin-2 selected-year maps must share the 2-by-3 layout.")
}

comparison_text <- paste(
  readLines(file.path("Rcode", "12_Previous_Final_Comparison.R"),
            warn = FALSE),
  collapse = "\n"
)
required_comparison_fragments <- c(
  '"report_output_config.R"',
  "apply_report_admin_name_map(",
  "info$report_admin_name_map"
)
missing_comparison_fragments <- required_comparison_fragments[!vapply(
  required_comparison_fragments,
  grepl,
  logical(1),
  x = comparison_text,
  fixed = TRUE
)]
if (length(missing_comparison_fragments) > 0L) {
  stop(
    "Previous-final appendix is missing configured display aliases: ",
    paste(missing_comparison_fragments, collapse = ", ")
  )
}

cat("Report output configuration tests passed.\n")
