source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

info_env <- new.env(parent = emptyenv())
load.country.info("Madagascar", envir = info_env)

data_dir <- country_data_dir(project_home(), "Madagascar")
poly_path <- resolve_country_data_path(info_env$poly.path, data_dir)

expected_path <- file.path(project_home(), "Data", "shapeFiles", "_alt")
if (!identical(poly_path, normalizePath(expected_path, winslash = "/", mustWork = FALSE))) {
  stop("Madagascar poly.path should point to Data/shapeFiles/_alt, got: ",
       poly_path)
}

stopifnot(identical(info_env$poly.path, "../shapeFiles/_alt"))
stopifnot(identical(info_env$poly.layer.adm0, "salb_MDG_0"))
stopifnot(identical(info_env$poly.layer.adm1, "salb_MDG_1"))
stopifnot(identical(info_env$poly.layer.adm2, "salb_MDG_2"))
stopifnot(identical(info_env$poly.label.adm1, "NAME_1"))
stopifnot(identical(info_env$poly.label.adm2, "NAME_2"))

cat("Madagascar Info JSON uses the normalized SALB boundary layers.\n")
