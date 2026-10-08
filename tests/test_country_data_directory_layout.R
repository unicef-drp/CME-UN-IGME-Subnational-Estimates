source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

test_country <- "Exampleland"
expected_country_dir <- file.path(project_home(), "Data", "Countries", test_country)

if (!identical(country_data_dir(project_home(), test_country), expected_country_dir)) {
  stop("country_data_dir should resolve to Data/Countries/<Country>.")
}

expected_dirs <- c(
  file.path(project_home(), "Data"),
  file.path(project_home(), "Data", "Countries"),
  expected_country_dir,
  file.path(expected_country_dir, "worldpop"),
  worldpop_raw_dir(test_country),
  population_raster_dir(test_country),
  file.path(project_home(), "Data", "shapeFiles"),
  file.path(project_home(), "Data", "MICS", test_country),
  file.path(project_home(), "Data", "DHS", test_country)
)

if (!identical(country_data_dirs(project_home(), test_country), expected_dirs)) {
  stop("country_data_dirs should include country directories under Data/Countries.")
}

shared_shape_path <- resolve_country_data_path(
  "../shapeFiles/georepo_TST_shp",
  expected_country_dir
)
expected_shape_path <- file.path(project_home(), "Data", "shapeFiles", "georepo_TST_shp")
if (!identical(shared_shape_path,
               normalizePath(expected_shape_path, winslash = "/", mustWork = FALSE))) {
  stop("../shapeFiles should resolve to the shared Data/shapeFiles folder.")
}

country_shape_path <- resolve_country_data_path(
  "shapeFiles/local_TST_shp",
  expected_country_dir
)
expected_country_shape_path <- file.path(expected_country_dir, "shapeFiles", "local_TST_shp")
if (!identical(country_shape_path,
               normalizePath(expected_country_shape_path, winslash = "/", mustWork = FALSE))) {
  stop("Country-local relative paths should resolve under Data/Countries/<Country>.")
}

cat("Country working data directories live under Data/Countries.\n")
