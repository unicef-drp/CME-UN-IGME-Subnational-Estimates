hiv_text <- paste(readLines(file.path("Data", "HIV", "format-factors.R"),
                            warn = FALSE),
                  collapse = "\n")

required_fragments <- c(
  "folder <- \"MM adjustment template 2025\"",
  "get_script_path <- function()",
  "setwd(dirname(get_script_path()))",
  "country == \"Cote dIvoire\"",
  "\"Cote_dIvoire\"",
  "has_subnational_area <- function(data, country_name)",
  "drop_mozambique_national",
  "drop_zimbabwe_national"
)

missing <- required_fragments[!vapply(required_fragments, grepl, logical(1),
                                      x = hiv_text, fixed = TRUE)]
if (length(missing) > 0) {
  stop("HIV formatter is missing recovered 2025/portable behavior: ",
       paste(missing, collapse = ", "))
}

if (grepl("rstudioapi::getActiveDocumentContext()", hiv_text, fixed = TRUE)) {
  stop("HIV formatter should not depend on the RStudio active document context.")
}

cat("HIV formatter uses the 2025 inputs and portable script path setup.\n")
