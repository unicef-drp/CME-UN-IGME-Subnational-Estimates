script_path <- file.path(
  "Rcode", "_script_for_specific_tasks", "Philippines_OCHA_Boundaries.R"
)
if (!file.exists(script_path)) {
  stop("Philippines OCHA preparation script is missing: ", script_path)
}

env <- new.env(parent = globalenv())
sys.source(script_path, envir = env)

square <- function(xmin, ymin, xmax, ymax) {
  sf::st_polygon(list(matrix(
    c(xmin, ymin, xmax, ymin, xmax, ymax, xmin, ymax, xmin, ymin),
    ncol = 2,
    byrow = TRUE
  )))
}

admin0 <- sf::st_sf(
  adm0_name = "Philippines",
  adm0_pcode = "PH",
  geometry = sf::st_sfc(square(120, 14, 121, 15), crs = 3857)
)
admin1 <- sf::st_sf(
  adm1_name = c("National Capital Region (NCR)", "Region I"),
  adm1_pcode = c("PH130000000", "PH010000000"),
  geometry = sf::st_sfc(
    square(120, 14, 120.4, 14.4),
    square(120.4, 14, 121, 15),
    crs = 3857
  )
)
admin2 <- sf::st_sf(
  adm1_name = c("National Capital Region (NCR)", "Region I"),
  adm1_pcode = c("PH130000000", "PH010000000"),
  adm2_name = c("City of Manila", "Ilocos Norte"),
  adm2_pcode = c("PH133900000", "PH012800000"),
  geometry = sf::st_sfc(
    square(120, 14, 120.4, 14.4),
    square(120.4, 14, 121, 15),
    crs = 3857
  )
)

layers <- env$normalize_philippines_ocha_layers(admin0, admin1, admin2)
stopifnot(
  identical(layers$admin0$NAME_0, "Philippines"),
  identical(layers$admin1$NAME_0, rep("Philippines", 2L)),
  identical(layers$admin1$NAME_1, admin1$adm1_name),
  identical(layers$admin2$NAME_1, admin2$adm1_name),
  identical(layers$admin2$NAME_2, admin2$adm2_name),
  identical(layers$admin2$adm2_pcode, admin2$adm2_pcode),
  identical(sf::st_crs(layers$admin2)$epsg, 4326L)
)

resource <- env$select_philippines_ocha_shp_resource(list(resources = list(
  list(
    id = "geojson",
    format = "GeoJSON",
    name = "GeoJSON",
    url = "https://x/geojson"
  ),
  list(
    id = "shp",
    format = "SHP",
    name = "COD-AB Philippines SHP",
    url = "https://x/shp.zip"
  )
)))
stopifnot(identical(resource$id, "shp"))

old_timeout <- getOption("timeout")
on.exit(options(timeout = old_timeout), add = TRUE)
options(timeout = 60)
observed_timeout <- NA_real_
download_target <- tempfile(fileext = ".zip")
if (!exists("download_philippines_ocha_archive", envir = env)) {
  stop("Large OCHA download helper is missing.")
}
env$download_philippines_ocha_archive(
  url = "https://example.test/phl.zip",
  destfile = download_target,
  download_file = function(url, destfile, ...) {
    observed_timeout <<- getOption("timeout")
    writeBin(charToRaw("synthetic archive"), destfile)
    invisible(0L)
  }
)
stopifnot(
  observed_timeout >= 200000,
  identical(getOption("timeout"), 60),
  file.exists(download_target),
  file.info(download_target)$size > 0
)

cat("Philippines OCHA boundary unit tests passed.\n")
