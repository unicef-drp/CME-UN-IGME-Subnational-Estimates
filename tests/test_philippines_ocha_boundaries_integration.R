script_path <- file.path(
  "Rcode", "_script_for_specific_tasks", "Philippines_OCHA_Boundaries.R"
)
if (!file.exists(script_path)) {
  stop("Philippines OCHA preparation script is missing: ", script_path)
}

env <- new.env(parent = globalenv())
sys.source(script_path, envir = env)

boundary_dir <- file.path("Data", "shapeFiles", "ocha_PHL_shp")
if (!dir.exists(boundary_dir)) {
  stop("Normalized Philippines OCHA boundary directory is missing: ",
       boundary_dir)
}

layers <- env$read_normalized_philippines_ocha_layers(boundary_dir)
dhs_ncr_points <- env$philippines_ocha_dhs_ncr_points(getwd())
validation <- env$validate_philippines_ocha_layers(
  layers,
  dhs_ncr_points = dhs_ncr_points
)

stopifnot(
  nrow(layers$admin0) == 1L,
  nrow(layers$admin1) == 17L,
  nrow(layers$admin2) == 88L,
  length(unique(layers$admin1$adm1_pcode)) == 17L,
  length(unique(layers$admin2$adm2_pcode)) == 88L,
  setequal(unique(layers$admin2$NAME_1), layers$admin1$NAME_1),
  identical(sf::st_crs(layers$admin2)$epsg, 4326L),
  all(sf::st_is_valid(layers$admin2)),
  sum(layers$admin1$NAME_1 == "National Capital Region (NCR)") == 1L,
  validation$ncr_area_km2 >= 500,
  validation$ncr_area_km2 <= 700,
  identical(validation$dhs_ncr_within, 126L)
)

metadata_path <- file.path(
  boundary_dir,
  "ocha_download_metadata.json"
)
if (!file.exists(metadata_path)) {
  stop("OCHA provenance metadata is missing: ", metadata_path)
}
metadata <- jsonlite::read_json(metadata_path, simplifyVector = TRUE)
stopifnot(
  identical(metadata$dataset_id, "cod-ab-phl"),
  identical(
    metadata$dataset_url,
    "https://data.humdata.org/dataset/cod-ab-phl"
  ),
  identical(metadata$normalized_layers$admin0, "ocha_PHL_0"),
  identical(metadata$normalized_layers$admin1, "ocha_PHL_1"),
  identical(metadata$normalized_layers$admin2, "ocha_PHL_2")
)

cat("Philippines OCHA boundary integration tests passed.\n")
