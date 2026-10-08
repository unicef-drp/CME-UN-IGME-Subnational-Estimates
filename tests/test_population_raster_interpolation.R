suppressPackageStartupMessages(library(terra))
source("Rcode/_supporting_scripts/population_raster_interpolation.R")

scratch <- tempfile("population-raster-interpolation-")
dir.create(scratch)
population_file <- function(year, age_group) {
  file.path(scratch, sprintf("test_%s_%s.tif", age_group, year))
}

template <- rast(nrows = 1, ncols = 2, xmin = 0, xmax = 2,
                 ymin = 0, ymax = 1, crs = "EPSG:4326")
for (age_group in c("u1", "u5")) {
  lower <- setValues(template, c(10, 20))
  upper <- setValues(template, c(30, 60))
  writeRaster(lower, population_file(2000L, age_group), overwrite = TRUE)
  writeRaster(upper, population_file(2002L, age_group), overwrite = TRUE)
}

complete_population_group_rasters(
  population_group_file = population_file,
  available_years = c(2000L, 2002L),
  target_years = 2000:2002
)

stopifnot(file.exists(population_file(2001L, "u1")))
stopifnot(all.equal(
  as.numeric(values(rast(population_file(2001L, "u1")))),
  c(20, 40)
))

cat("Population-raster interpolation tests passed.\n")
