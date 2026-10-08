old_worldpop_home <- Sys.getenv("UN_SUBNATIONAL_WORLDPOP_HOME", unset = NA_character_)
on.exit({
  if (is.na(old_worldpop_home)) {
    Sys.unsetenv("UN_SUBNATIONAL_WORLDPOP_HOME")
  } else {
    Sys.setenv(UN_SUBNATIONAL_WORLDPOP_HOME = old_worldpop_home)
  }
}, add = TRUE)

test_root <- tempfile("worldpop-home-")
Sys.setenv(UN_SUBNATIONAL_WORLDPOP_HOME = test_root)

source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

expected_root <- normalizePath(test_root, winslash = "/", mustWork = FALSE)
expected_raw <- file.path(expected_root, "Global1_2000_2020", "Exampleland")
expected_population <- file.path(expected_root, "Population", "Exampleland")

if (!identical(worldpop_data_home(), expected_root)) {
  stop("worldpop_data_home should honor UN_SUBNATIONAL_WORLDPOP_HOME.")
}
if (!identical(worldpop_raw_dir("Exampleland"), expected_raw)) {
  stop("worldpop_raw_dir should use Global1_2000_2020/<Country>.")
}
if (!identical(population_raster_dir("Exampleland"), expected_population)) {
  stop("population_raster_dir should use Population/<Country>.")
}

country_dirs <- country_data_dirs(project_home(), "Exampleland")
country_output <- file.path(country_data_dir(project_home(), "Exampleland"), "worldpop")
if (!all(c(country_output, expected_raw, expected_population) %in% country_dirs)) {
  stop("country_data_dirs should keep weight output and add both TIFF directories.")
}

cat("WorldPop TIFF paths resolve to centralized country directories.\n")
