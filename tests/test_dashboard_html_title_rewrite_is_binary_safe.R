script_path <- file.path("Rcode", "9_Comparison_Plot.R")
script_lines <- readLines(script_path, warn = FALSE)
script_text <- paste(script_lines, collapse = "\n")

if (grepl("readLines\\(comparison\\.html", script_text)) {
  stop("Dashboard title rewrite must not use readLines() on self-contained HTML.")
}

if (grepl("writeLines\\(html", script_text)) {
  stop("Dashboard title rewrite must not use writeLines() on self-contained HTML.")
}

if (!grepl("readBin\\(\\s*comparison\\.html", script_text, perl = TRUE)) {
  stop("Dashboard title rewrite should read the rendered HTML as raw bytes.")
}

if (!grepl("writeBin\\(", script_text)) {
  stop("Dashboard title rewrite should write raw bytes back to the rendered HTML.")
}

message("Dashboard HTML title rewrite is binary-safe.")
