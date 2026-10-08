boundary_dir <- file.path("Data", "shapeFiles", "georepo_GAB_shp")

admin1 <- sf::st_read(
  boundary_dir,
  layer = "georepo_GAB_1",
  quiet = TRUE
)
admin2 <- sf::st_read(
  boundary_dir,
  layer = "georepo_GAB_2",
  quiet = TRUE
)
raw_admin1 <- sf::st_read(
  file.path(boundary_dir, "gab_admin1_georepo.geojson"),
  quiet = TRUE
)

admin1_names <- as.character(admin1$NAME_1)
admin2_parents <- as.character(admin2$NAME_1)

stopifnot(
  nrow(raw_admin1) == 10L,
  sum(grepl("Lolo", as.character(raw_admin1$name), fixed = TRUE)) == 2L,
  nrow(admin1) == 9L,
  !anyDuplicated(admin1_names),
  sum(grepl("Lolo", admin1_names, fixed = TRUE)) == 1L,
  nrow(admin2) == 48L,
  all(unique(admin2_parents) %in% admin1_names),
  sum(grepl("Lolo", admin2_parents, fixed = TRUE)) == 4L,
  all(sf::st_is_valid(admin1)),
  all(sf::st_is_valid(admin2)),
  !any(sf::st_is_empty(admin1)),
  !any(sf::st_is_empty(admin2))
)

cat(
  "Gabon GeoRepo duplicate Ogooue-Lolo pieces are normalized to one ",
  "Admin-1 while retaining all 48 Admin-2 areas.\n",
  sep = ""
)
