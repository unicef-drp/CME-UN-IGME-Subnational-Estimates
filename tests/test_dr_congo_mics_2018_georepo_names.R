library(sf)

mics_file <- file.path("Data", "MICS", "DR_Congo", "cod.2018.tmp.rda")
shape_dir <- file.path("Data", "shapeFiles", "georepo_COD_shp")

stopifnot(file.exists(mics_file))

mics_env <- new.env(parent = emptyenv())
load(mics_file, envir = mics_env)
stopifnot(exists("dat.tmp", envir = mics_env, inherits = FALSE))

dat.tmp <- get("dat.tmp", envir = mics_env, inherits = FALSE)
poly.adm1 <- st_read(shape_dir, "georepo_COD_1", quiet = TRUE)

stopifnot(
  nrow(dat.tmp) == 77495L,
  identical(sort(unique(dat.tmp$survey)), 2018),
  identical(sort(unique(as.character(dat.tmp$urban))), c("rural", "urban"))
)

mics_names <- sort(unique(as.character(dat.tmp$admin1.name)))
georepo_names <- sort(unique(as.character(poly.adm1$NAME_1)))

if (!all(mics_names %in% georepo_names)) {
  stop(
    "DR Congo MICS 2018 Admin1 names do not match GeoRepo: ",
    paste(setdiff(mics_names, georepo_names), collapse = ", ")
  )
}

stopifnot(length(mics_names) == 26L)
stopifnot(all(c(
  "Equateur",
  "Kasai",
  "Kasai Central",
  "Kasai Oriental",
  "Kongo Central"
) %in% mics_names))
stopifnot(!any(c(
  "Équateur",
  "Kasaï",
  "Kasaï-Central",
  "Kasaï-Oriental",
  "Kongo-Central"
) %in% mics_names))

message("DR Congo MICS 2018 Admin1 names match the GeoRepo hierarchy.")
