script_text <- paste(readLines("Rcode/9_Comparison_Plot.R", warn = FALSE), collapse = "\n")

stopifnot(grepl("output_file = basename(comparison.html)", script_text, fixed = TRUE))
stopifnot(grepl('"--output-dir"', script_text, fixed = TRUE))
stopifnot(!grepl("output_file = comparison.html", script_text, fixed = TRUE))
stopifnot(!grepl("output_dir = dirname(comparison.html)", script_text, fixed = TRUE))

cat("Quarto dashboard rendering uses a plain output filename and CLI output-dir.\n")
