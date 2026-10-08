script <- paste(
  readLines(file.path("Rcode", "9_Comparison_Plot.R"), warn = FALSE),
  collapse = "\n"
)

required_fragments <- c(
  "smoothed_direct_observed_cutoff <- max((beg.period.years + end.period.years) / 2)",
  "sd.adm1.to.natl.frame$years <= smoothed_direct_observed_cutoff",
  "sd.adm1.yl.to.natl.frame$years <= smoothed_direct_observed_cutoff"
)

missing <- required_fragments[
  !vapply(required_fragments, grepl, logical(1), x = script, fixed = TRUE)
]

if (length(missing) > 0) {
  stop(
    paste(
      "Admin-1 smoothed-direct dashboard aggregates should stop at the",
      "last observed-period midpoint. Missing:",
      paste(missing, collapse = "; ")
    )
  )
}

if (grepl('lines(pane.years,tmp$median', script, fixed = TRUE) ||
    grepl('lines(plot.years,tmp$median', script, fixed = TRUE) ||
    grepl('points(pane.years,tmp$median', script, fixed = TRUE) ||
    grepl('points(plot.years,tmp$median', script, fixed = TRUE)) {
  stop("Static comparison traces should use each method's own supported years.")
}

if (!grepl('lines(tmp$years,tmp$median_nmr', script, fixed = TRUE) ||
    !grepl('lines(tmp$years,tmp$median_u5', script, fixed = TRUE)) {
  stop("Static comparison traces should plot their estimates against tmp$years.")
}

message("Comparison dashboard limits Admin-1 smoothed-direct series to observed support.")
