library(sf)

mics_file <- file.path("Data", "MICS", "Togo", "tgo.2017.tmp.rda")
shape_dir <- file.path("Data", "shapeFiles", "georepo_TGO_shp")

stopifnot(file.exists(mics_file))

mics_env <- new.env(parent = emptyenv())
load(mics_file, envir = mics_env)
stopifnot(exists("dat.tmp", envir = mics_env, inherits = FALSE))

dat.tmp <- get("dat.tmp", envir = mics_env, inherits = FALSE)
poly.adm1 <- st_read(shape_dir, "georepo_TGO_1", quiet = TRUE)

mics_names <- sort(unique(as.character(dat.tmp$admin1.name)))
georepo_names <- sort(unique(as.character(poly.adm1$NAME_1)))

if (!all(mics_names %in% georepo_names)) {
  stop(
    "Togo MICS 2017 Admin1 names do not match GeoRepo: ",
    paste(setdiff(mics_names, georepo_names), collapse = ", ")
  )
}

stopifnot("Centrale" %in% mics_names)
stopifnot(!("Centre" %in% mics_names))

message("Togo MICS 2017 Admin1 names match the GeoRepo hierarchy.")
