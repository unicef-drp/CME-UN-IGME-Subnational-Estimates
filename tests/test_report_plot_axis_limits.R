source("Rcode/_supporting_scripts/Report_Plot_00.R")

direct_frame <- data.frame(
  region = c("admin2_1", "admin2_2"),
  region.orig = c("Display A", "Display B"),
  median_nmr = c(0.21, 0.04)
)

direct_values <- report_direct_region_values(
  direct_frame,
  area = "admin2_1",
  outcome = "nmr"
)

stopifnot(identical(direct_values, 0.21))

axis_max <- report_spaghetti_axis_max(
  model_median = c(35, 30),
  model_upper = c(55, 50),
  direct_values = 1000 * direct_values,
  margin = 25
)

stopifnot(identical(axis_max, 235))
stopifnot(identical(
  report_spaghetti_axis_max(NA_real_, NA_real_, NA_real_),
  25
))

cat("report plot axis-limit tests passed\n")
