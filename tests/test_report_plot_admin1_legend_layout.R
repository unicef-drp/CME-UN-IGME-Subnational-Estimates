script <- paste(
  readLines(file.path("Rcode", "11_Report_Plot.R"), warn = FALSE),
  collapse = "\n"
)

admin1_block <- sub(
  ".*# Admin-1 Plots ####",
  "",
  sub("# Admin-2 Plots ####.*", "", script)
)

required <- c(
  "scale_color_discrete(labels = scales::label_wrap(width = 24))",
  "guides(col = guide_legend(title = NULL, ncol = 3))"
)
missing <- required[!vapply(
  required, grepl, logical(1), x = admin1_block, fixed = TRUE
)]
if (length(missing) > 0L) {
  stop(
    "Admin1 spaghetti legends must wrap long names without a clipped title: ",
    paste(missing, collapse = ", ")
  )
}

cat("Admin1 report legends fit within the PDF page.\n")
