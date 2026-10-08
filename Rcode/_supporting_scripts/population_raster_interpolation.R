complete_population_group_rasters <- function(
    population_group_file,
    available_years,
    target_years,
    age_groups = c("u1", "u5")) {
  available_years <- sort(unique(as.integer(available_years)))
  target_years <- sort(unique(as.integer(target_years)))
  if (length(available_years) == 0L || anyNA(available_years) || anyNA(target_years)) {
    stop("Population raster years must be finite integers.", call. = FALSE)
  }

  for (age_group in age_groups) {
    available_files <- vapply(
      available_years,
      function(year) population_group_file(year, age_group),
      character(1)
    )
    if (!all(file.exists(available_files))) {
      stop("Missing anchor population rasters for ", age_group, ".", call. = FALSE)
    }

    for (year in setdiff(target_years, available_years)) {
      output_file <- population_group_file(year, age_group)
      if (file.exists(output_file)) {
        next
      }
      lower_years <- available_years[available_years < year]
      upper_years <- available_years[available_years > year]
      lower_year <- if (length(lower_years) > 0L) max(lower_years) else min(available_years)
      upper_year <- if (length(upper_years) > 0L) min(upper_years) else max(available_years)

      lower <- terra::rast(population_group_file(lower_year, age_group))
      if (identical(lower_year, upper_year)) {
        interpolated <- lower
      } else {
        upper <- terra::rast(population_group_file(upper_year, age_group))
        if (!isTRUE(terra::compareGeom(lower, upper, stopOnError = FALSE))) {
          stop("Population raster geometry differs between ", lower_year,
               " and ", upper_year, ".", call. = FALSE)
        }
        fraction <- (year - lower_year) / (upper_year - lower_year)
        interpolated <- lower + fraction * (upper - lower)
      }

      dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
      terra::writeRaster(interpolated, output_file, overwrite = TRUE)
      message("Interpolated ", age_group, " population raster for ", year,
              " from ", lower_year, " and ", upper_year)
    }
  }
  invisible(TRUE)
}
