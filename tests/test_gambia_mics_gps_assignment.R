project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
Sys.setenv(UN_SUBNATIONAL_HOME = project_dir)

source(file.path(
  "Rcode",
  "_script_for_specific_tasks",
  "MICS_Geospatial_DataProcessing.R"
))

gps_path <- file.path(
  "Data",
  "MICS",
  "Gambia",
  "2018",
  "GambiaMICS2018GPS.shp"
)
stopifnot(file.exists(gps_path))

boundaries <- load_country_georepo_boundaries("Gambia")
gps <- read_mics_gps_clusters(gps_path)$data

dummy_births <- data.frame(
  cluster = gps$cluster,
  age = 0,
  years = 2018,
  total = 1,
  Y = 0,
  v005 = 1,
  urban = "urban",
  survey = 2018
)

assigned <- assign_mics_geospatial_admins(
  dummy_births,
  gps_path,
  boundaries$poly.adm1,
  boundaries$poly.label.adm1,
  boundaries$poly.adm2,
  boundaries$poly.label.adm2
)

expected_parent <- as.character(
  boundaries$poly.adm2$NAME_1[assigned$admin2]
)

stopifnot(
  nrow(assigned) == 390L,
  length(unique(assigned$cluster)) == 390L,
  all(is.finite(assigned$LONGNUM)),
  all(is.finite(assigned$LATNUM)),
  length(unique(assigned$admin1.name)) == 8L,
  length(unique(assigned$admin2.name)) == 36L,
  identical(as.character(assigned$admin1.name), expected_parent)
)

cat(
  "Gambia MICS 2018 GPS assigns all 390 clusters with consistent GeoRepo parents.\n"
)
