script_env <- new.env(parent = globalenv())
source(
  file.path(
    "Rcode", "_script_for_specific_tasks",
    "MICS_Geospatial_DataProcessing.R"
  ),
  local = script_env
)

invalid_name <- rawToChar(as.raw(c(0x4d, 0x72, 0xe9, 0x6d, 0x61, 0x6e, 0x69)))
Encoding(invalid_name) <- "UTF-8"

polygon <- sf::st_sf(
  NAME_2 = invalid_name,
  geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0)
  ))), crs = 4326)
)
point <- sf::st_sf(
  cluster = 1L,
  geometry = sf::st_sfc(sf::st_point(c(0.5, 0.5)), crs = 4326)
)

assigned <- script_env$assign_points_to_admin(
  point, polygon, "NAME_2", "admin2"
)
expected_name <- rawToChar(as.raw(c(
  0x4d, 0x72, 0xc3, 0xa9, 0x6d, 0x61, 0x6e, 0x69
)))
Encoding(expected_name) <- "UTF-8"

stopifnot(
  validUTF8(assigned$admin.name),
  identical(assigned$admin.name, expected_name)
)

message("MICS geospatial UTF-8 boundary-name test passed")
