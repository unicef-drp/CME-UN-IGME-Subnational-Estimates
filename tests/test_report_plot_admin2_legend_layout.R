script <- paste(readLines(file.path("Rcode", "11_Report_Plot.R"), warn = FALSE),
                collapse = "\n")

required <- c(
  "scales::label_wrap(width = 24)",
  "legend.text = element_text(size = 6)"
)

missing <- required[!vapply(required, grepl, logical(1),
                            x = script, fixed = TRUE)]
if (length(missing) > 0) {
  stop("Admin2 spaghetti legends need wrapping for long area names: ",
       paste(missing, collapse = ", "))
}

cat("Admin2 report legends wrap long area names within the PDF page.\n")
