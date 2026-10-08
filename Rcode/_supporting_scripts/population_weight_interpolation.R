complete_population_weights <- function(weight_table, target_years) {
  required_columns <- c("region", "proportion", "years")
  missing_columns <- setdiff(required_columns, names(weight_table))
  if (length(missing_columns) > 0L) {
    stop(
      "Population weights are missing columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  target_years <- sort(unique(as.integer(target_years)))
  if (length(target_years) == 0L || anyNA(target_years)) {
    stop("Target population-weight years must be finite integers.", call. = FALSE)
  }
  if (anyDuplicated(weight_table[c("region", "years")])) {
    stop("Population weights contain duplicate region-year rows.", call. = FALSE)
  }

  region_tables <- lapply(unique(as.character(weight_table$region)), function(region) {
    region_data <- weight_table[weight_table$region == region, required_columns]
    region_data <- region_data[order(region_data$years), ]
    if (nrow(region_data) == 1L) {
      proportions <- rep(region_data$proportion, length(target_years))
    } else {
      proportions <- stats::approx(
        x = region_data$years,
        y = region_data$proportion,
        xout = target_years,
        method = "linear",
        rule = 2,
        ties = "ordered"
      )$y
    }
    data.frame(
      region = region,
      proportion = proportions,
      years = target_years,
      stringsAsFactors = FALSE
    )
  })

  completed <- do.call(rbind, region_tables)
  year_totals <- stats::aggregate(proportion ~ years, completed, sum)
  normalization <- year_totals$proportion[match(completed$years, year_totals$years)]
  if (any(!is.finite(normalization)) || any(normalization <= 0)) {
    stop("Interpolated population weights have invalid annual totals.", call. = FALSE)
  }
  completed$proportion <- completed$proportion / normalization
  completed[order(completed$years, completed$region), required_columns]
}
