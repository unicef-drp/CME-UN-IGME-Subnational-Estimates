output_file <- file.path(
  "Data", "MICS", "Eswatini", "2022", "swz.2022.geo.tmp.rda"
)

if (!file.exists(output_file)) {
  stop("Eswatini MICS 2022 preprocessed file is missing.")
}

output_env <- new.env(parent = emptyenv())
load(output_file, envir = output_env)
if (!exists("dat.tmp", envir = output_env, inherits = FALSE)) {
  stop("Eswatini MICS 2022 output must contain dat.tmp.")
}

dat.tmp <- get("dat.tmp", envir = output_env)
required <- c(
  "cluster", "age", "years", "total", "Y", "v005", "urban",
  "LONGNUM", "LATNUM", "strata", "admin1", "admin2",
  "admin1.char", "admin2.char", "admin1.name", "admin2.name",
  "survey", "survey.type"
)
stopifnot(all(required %in% names(dat.tmp)))
stopifnot(nrow(dat.tmp) > 0L)
stopifnot(identical(sort(unique(dat.tmp$survey)), 2022))
stopifnot(all(is.finite(dat.tmp$v005)), all(dat.tmp$v005 > 0))
stopifnot(all(is.finite(dat.tmp$total)), all(dat.tmp$total >= 0))
stopifnot(all(is.finite(dat.tmp$Y)), all(dat.tmp$Y >= 0))
stopifnot(all(dat.tmp$Y <= dat.tmp$total))
stopifnot(!anyNA(dat.tmp$cluster))
stopifnot(length(unique(dat.tmp$cluster)) == 350L)
stopifnot(!anyNA(dat.tmp$LONGNUM), !anyNA(dat.tmp$LATNUM))
stopifnot(!anyNA(dat.tmp$admin1), !anyNA(dat.tmp$admin2))
stopifnot(!anyNA(dat.tmp$admin1.char), !anyNA(dat.tmp$admin2.char))
stopifnot(!anyNA(dat.tmp$admin1.name))
stopifnot(!anyNA(dat.tmp$admin2.name), !anyNA(dat.tmp$strata))
stopifnot(all(dat.tmp$survey.type == "MICS"))
stopifnot(
  identical(
    sort(unique(as.character(dat.tmp$admin1.name))),
    c("Hhohho", "Lubombo", "Manzini", "Shiselweni")
  )
)
stopifnot(length(unique(dat.tmp$admin2.name)) == 59L)
cluster_coords <- unique(dat.tmp[, c("cluster", "LONGNUM", "LATNUM")])
stopifnot(!any(duplicated(cluster_coords$cluster)))

cat("Eswatini MICS 2022 geospatial Admin-2 preprocessing contract passed.\n")
