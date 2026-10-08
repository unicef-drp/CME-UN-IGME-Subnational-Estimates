source("Rcode/_supporting_scripts/population_weight_interpolation.R")

anchors <- data.frame(
  region = c("A", "B", "A", "B"),
  proportion = c(0.2, 0.8, 0.4, 0.6),
  years = c(2000L, 2000L, 2002L, 2002L)
)

completed <- complete_population_weights(anchors, 1999:2003)
stopifnot(identical(sort(unique(completed$years)), 1999:2003))
stopifnot(nrow(completed) == 10L)

a <- completed[completed$region == "A", ]
stopifnot(all.equal(a$proportion[a$years == 1999L], 0.2))
stopifnot(all.equal(a$proportion[a$years == 2001L], 0.3))
stopifnot(all.equal(a$proportion[a$years == 2003L], 0.4))

year_sums <- aggregate(proportion ~ years, completed, sum)
stopifnot(all(abs(year_sums$proportion - 1) < 1e-12))

single_year <- anchors[anchors$years == 2000L, ]
single_completed <- complete_population_weights(single_year, 2000:2002)
stopifnot(all(single_completed$proportion[single_completed$region == "A"] == 0.2))

admin_script <- paste(readLines("Rcode/5_Admin_Weights_sf.R", warn = FALSE),
                      collapse = "\n")
stopifnot(grepl(
  "admin_names$Internal",
  admin_script,
  fixed = TRUE
))

cat("Population-weight interpolation tests passed.\n")
