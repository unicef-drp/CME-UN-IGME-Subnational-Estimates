admin1_path <- file.path(
  "Data", "shapeFiles", "georepo_RWA_shp",
  "rwa_admin1_georepo.geojson"
)
admin2_path <- file.path(
  "Data", "shapeFiles", "georepo_RWA_shp",
  "rwa_admin2_georepo.geojson"
)
stopifnot(file.exists(admin1_path), file.exists(admin2_path))

env <- new.env(parent = globalenv())
env$country <- "Rwanda"
env$iso0 <- "RWA"
sys.source("Rcode/2_download_georepo_shapefiles.R", envir = env)

admin1 <- sf::st_read(admin1_path, quiet = TRUE)
admin2 <- sf::st_read(admin2_path, quiet = TRUE)
prepared <- env$prepare_georepo_layers(
  admin1,
  admin2,
  "Rwanda",
  list(list(
    level = 2L,
    name = "Under National Administration",
    reason = "GeoRepo feature is not an official Rwanda district"
  ))
)
admin0 <- env$repair_layer_geometry(prepared$admin0)

stopifnot(
  nrow(prepared$admin1) == 5L,
  nrow(prepared$admin2) == 30L,
  all(sf::st_is_valid(admin0)),
  all(sf::st_is_valid(prepared$admin1)),
  all(sf::st_is_valid(prepared$admin2)),
  !"Under National Administration" %in% prepared$admin2$NAME_2
)
