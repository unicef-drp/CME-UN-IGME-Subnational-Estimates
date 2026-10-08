source(file.path(
  "Rcode", "_supporting_scripts", "direct_smoothing_inputs.R"
))

zero_edges <- matrix(0, 3, 3)
rownames(zero_edges) <- colnames(zero_edges) <- paste0("admin1_", 1:3)
connected <- zero_edges
connected[1, 2] <- connected[2, 1] <- 1

stopifnot(
  !adjacency_has_edges(zero_edges),
  adjacency_has_edges(connected)
)

direct_data <- data.frame(
  region = rep(c("admin1_1", "admin1_2"), each = 2),
  years = rep(c("2000-2001", "2002-2004"), 2),
  mean = c(0.05, 0.04, 0.06, 0.05)
)

fitted <- smooth_direct_independently(
  data = direct_data,
  region_names = c("admin1_1", "admin1_2"),
  fit_region = function(region_data, region_name) {
    stopifnot(all(region_data$region == "All"))
    list(
      fit = paste("fit", region_name),
      result = data.frame(
        region = "All",
        years = region_data$years,
        median = region_data$mean
      )
    )
  }
)

stopifnot(
  identical(names(fitted$fit), c("admin1_1", "admin1_2")),
  identical(unique(fitted$result$region), c("admin1_1", "admin1_2")),
  nrow(fitted$result) == nrow(direct_data)
)

pipeline_script <- paste(
  readLines(file.path("Rcode", "4_Direct_SmoothDirect_sf.R"), warn = FALSE),
  collapse = "\n"
)
required_integration <- c(
  "fit_admin_period_smoothed_direct <- function(",
  "if (adjacency_has_edges(Amat))",
  "smooth_direct_independently("
)
stopifnot(vapply(
  required_integration,
  grepl,
  logical(1),
  x = pipeline_script,
  fixed = TRUE
))

message("Disconnected-region direct-smoothing helper tests passed")
