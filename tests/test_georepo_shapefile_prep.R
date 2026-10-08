repo_root <- normalizePath(file.path(getwd()), winslash = "/", mustWork = TRUE)
script_path <- file.path(repo_root, "Rcode", "2_download_georepo_shapefiles.R")

env <- new.env(parent = globalenv())
env$country <- "Nigeria"
env$iso0 <- "NGA"
sys.source(script_path, envir = env)

old_project_home <- Sys.getenv("UN_SUBNATIONAL_HOME", unset = NA_character_)
test_project_home <- normalizePath(
  file.path(tempdir(), "georepo-project-home"),
  winslash = "/",
  mustWork = FALSE
)
Sys.setenv(UN_SUBNATIONAL_HOME = test_project_home)
resolved_project_home <- env$georepo_project_home(
  file.path(tempdir(), "nested", "pipeline-entry.R")
)
if (is.na(old_project_home)) {
  Sys.unsetenv("UN_SUBNATIONAL_HOME")
} else {
  Sys.setenv(UN_SUBNATIONAL_HOME = old_project_home)
}
stopifnot(identical(resolved_project_home, test_project_home))

stopifnot(identical(
  env$georepo_output_dir("C:/repo", "NGA"),
  "C:/repo/Data/shapeFiles/georepo_NGA_shp"
))

stopifnot(identical(
  env$normalised_layer_name("NGA", 1),
  "georepo_NGA_1"
))

stopifnot(identical(env$GEOREPO_VIEW_UUID_DEFAULT, "3632361a-b26f-4568-82b1-391a784a6299"))
stopifnot(identical(env$country_folder_name("NGA", "Nigeria"), "NGA_Nigeria"))

queries <- env$candidate_country_queries("NGA", "Nigeria")
stopifnot("NGA" %in% queries)
stopifnot("Nigeria" %in% queries)

lookup_calls <- 0L
env$get_json_url <- function(url, attempts = 4) {
  lookup_calls <<- lookup_calls + 1L
  if (lookup_calls == 1L) {
    return(list(results = list(list(
      ucode = "xSK_V1",
      admin_level = 0L,
      name = "Senkaku Islands"
    ))))
  }
  list(results = list(list(
    ucode = "SEN_V1",
    admin_level = 0L,
    name = "Senegal"
  )))
}
senegal_match <- env$find_country_feature(
  "https://example.invalid",
  "view-uuid",
  "SEN",
  "Senegal"
)
stopifnot(
  identical(senegal_match$feature$ucode, "SEN_V1"),
  identical(senegal_match$matched_query, "Senegal"),
  lookup_calls == 2L
)

children_url <- env$children_url("https://georepo.unicef.org/api/v1", "view-uuid", "NGA_V1")
stopifnot(grepl("/search/view/view-uuid/entity/NGA_V1/children/", children_url, fixed = TRUE))
stopifnot(grepl("geom=full_geom", children_url, fixed = TRUE))
stopifnot(grepl("format=geojson", children_url, fixed = TRUE))

adm0 <- data.frame(dummy = 1)
adm0_prepped <- env$prepare_layer(adm0, level = 0, country = "Nigeria")
stopifnot(identical(adm0_prepped$NAME_0, "Nigeria"))

invalid_geometry <- sf::st_as_sfc(
  "POLYGON((0 0, 2 0, 2 2, 1 1, 0 2, 1 1, 0 0))",
  crs = 4326
)
invalid_layer <- sf::st_sf(name = "self-intersection", geometry = invalid_geometry)
stopifnot(!all(sf::st_is_valid(invalid_layer)))

repaired_layer <- env$repair_layer_geometry(invalid_layer)
stopifnot(
  inherits(repaired_layer, "sf"),
  nrow(repaired_layer) == nrow(invalid_layer),
  all(sf::st_is_valid(repaired_layer))
)

duplicate_vertex_geometry <- sf::st_as_sfc(
  "MULTIPOLYGON(((0 0, 2 0, 2 0, 2 2, 0 2, 0 0)))",
  crs = 4326
)
duplicate_admin1 <- sf::st_sf(
  name = "Duplicate Region",
  geometry = duplicate_vertex_geometry
)
duplicate_admin2 <- sf::st_sf(
  name = "Duplicate District",
  admin1_name_from_pull = "Duplicate Region",
  geometry = duplicate_vertex_geometry
)
duplicate_prepared <- env$prepare_georepo_layers(
  duplicate_admin1,
  duplicate_admin2,
  "Test Country"
)
stopifnot(
  all(sf::st_is_valid(duplicate_prepared$admin0)),
  all(sf::st_is_valid(duplicate_prepared$admin1)),
  all(sf::st_is_valid(duplicate_prepared$admin2))
)

mixed_dimension_geometry <- sf::st_as_sfc(
  paste0(
    "GEOMETRYCOLLECTION(",
    "POLYGON((0 0, 2 0, 2 2, 0 2, 0 0)),",
    "LINESTRING(0 0, 2 2))"
  ),
  crs = 4326
)
mixed_dimension_layer <- sf::st_sf(
  name = "Mixed Dimension",
  geometry = mixed_dimension_geometry
)
mixed_dimension_repaired <- env$repair_layer_geometry(mixed_dimension_layer)
stopifnot(
  nrow(mixed_dimension_repaired) == 1L,
  all(
    sf::st_geometry_type(mixed_dimension_repaired) %in%
      c("POLYGON", "MULTIPOLYGON")
  ),
  all(sf::st_is_valid(mixed_dimension_repaired))
)

multi_polygon_component_geometry <- sf::st_as_sfc(
  paste0(
    "GEOMETRYCOLLECTION(",
    "POLYGON((0 0, 1 0, 1 1, 0 1, 0 0)),",
    "POLYGON((2 0, 3 0, 3 1, 2 1, 2 0)),",
    "LINESTRING(0 0, 3 1))"
  ),
  crs = 4326
)
multi_polygon_component_layer <- sf::st_sf(
  name = "Multiple Polygon Components",
  geometry = multi_polygon_component_geometry
)
multi_polygon_component_repaired <- env$repair_layer_geometry(
  multi_polygon_component_layer
)
stopifnot(
  nrow(multi_polygon_component_repaired) == 1L,
  sf::st_geometry_type(multi_polygon_component_repaired) %in%
    c("POLYGON", "MULTIPOLYGON"),
  sf::st_is_valid(multi_polygon_component_repaired)
)

near_degenerate_component_geometry <- sf::st_as_sfc(
  paste0(
    "GEOMETRYCOLLECTION(",
    "POLYGON((39.1 -7.1, 39.2 -7.1, 39.2 -7, 39.1 -7, 39.1 -7.1)),",
    "POLYGON((39.2363 -6.9128, 39.2362 -6.9126, ",
    "39.2362 -6.912599999999995, 39.2363 -6.9128)),",
    "LINESTRING(39.1 -7.1, 39.2 -7))"
  ),
  crs = 4326
)
near_degenerate_component_layer <- sf::st_sf(
  name = "Near-degenerate Polygon Component",
  geometry = near_degenerate_component_geometry
)
near_degenerate_component_repaired <- env$repair_layer_geometry(
  near_degenerate_component_layer
)
stopifnot(
  sf::st_geometry_type(near_degenerate_component_repaired) %in%
    c("POLYGON", "MULTIPOLYGON"),
  as.numeric(sf::st_area(near_degenerate_component_repaired)) > 0,
  sf::st_is_valid(near_degenerate_component_repaired)
)

admin1_layer <- sf::st_sf(
  NAME_1 = c("Bomi", "Under National Administration"),
  geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 0)))),
    sf::st_polygon(list(rbind(c(1, 0), c(2, 0), c(2, 1), c(1, 0)))),
    crs = 4326
  )
)
admin2_layer <- sf::st_sf(
  NAME_1 = c("Bomi", "Under National Administration", "Bomi"),
  NAME_2 = c("Bomi Child A", "Excluded Child", "Bomi Child B"),
  geometry = sf::st_sfc(
    sf::st_point(c(0.2, 0.2)),
    sf::st_point(c(1.2, 0.2)),
    sf::st_point(c(0.4, 0.4)),
    crs = 4326
  )
)
exclusions <- data.frame(
  level = 1L,
  name = "Under National Administration",
  reason = "GeoRepo feature is not an official Liberia county",
  stringsAsFactors = FALSE
)

unchanged <- env$apply_georepo_boundary_exclusions(
  admin1_layer, admin2_layer, NULL
)
stopifnot(
  nrow(unchanged$admin1) == 2L,
  nrow(unchanged$admin2) == 3L,
  unchanged$counts$admin1_before == 2L,
  unchanged$counts$admin1_after == 2L
)

filtered <- env$apply_georepo_boundary_exclusions(
  admin1_layer, admin2_layer, exclusions
)
stopifnot(
  identical(filtered$admin1$NAME_1, "Bomi"),
  identical(filtered$admin2$NAME_2, c("Bomi Child A", "Bomi Child B")),
  filtered$counts$admin1_before == 2L,
  filtered$counts$admin1_after == 1L,
  filtered$counts$admin2_before == 3L,
  filtered$counts$admin2_after == 2L,
  identical(filtered$exclusions$name, "Under National Administration")
)

admin2_exclusions <- data.frame(
  level = 2L,
  name = "Bomi Child B",
  reason = "Synthetic Admin-2 exclusion test",
  stringsAsFactors = FALSE
)
filtered_admin2 <- env$apply_georepo_boundary_exclusions(
  admin1_layer, admin2_layer, admin2_exclusions
)
stopifnot(
  nrow(filtered_admin2$admin1) == 2L,
  identical(
    filtered_admin2$admin2$NAME_2,
    c("Bomi Child A", "Excluded Child")
  ),
  filtered_admin2$counts$admin2_before == 3L,
  filtered_admin2$counts$admin2_after == 2L
)

missing_name_error <- try(
  env$apply_georepo_boundary_exclusions(
    admin1_layer,
    admin2_layer,
    transform(exclusions, name = "Missing Area")
  ),
  silent = TRUE
)
stopifnot(
  inherits(missing_name_error, "try-error"),
  grepl("Missing Area", as.character(missing_name_error), fixed = TRUE)
)

reserved_name_alias_layer <- sf::st_sf(
  name = "Garden Route",
  name_1 = "Garden Route",
  name_2 = "Garden Route",
  admin1_name_from_pull = "Western Cape",
  geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(
      c(18, -34), c(19, -34), c(19, -33), c(18, -34)
    ))),
    crs = 4326
  )
)
reserved_name_output_dir <- tempfile("georepo-field-names-")
dir.create(reserved_name_output_dir)
written_layer_name <- env$write_normalised_layer(
  reserved_name_alias_layer,
  reserved_name_output_dir,
  "TST",
  2,
  "Test Country"
)
written_layer <- sf::st_read(
  file.path(reserved_name_output_dir, paste0(written_layer_name, ".shp")),
  quiet = TRUE
)
stopifnot(
  all(c("NAME_1", "NAME_2") %in% names(written_layer)),
  !any(c("name_1", "name_2") %in% names(written_layer)),
  identical(as.character(written_layer$NAME_1), "Western Cape"),
  identical(as.character(written_layer$NAME_2), "Garden Route")
)

message("GeoRepo shapefile prep helper tests passed.")
