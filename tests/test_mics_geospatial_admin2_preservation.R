source(file.path("Rcode", "_supporting_scripts", "mics_admin_matching.R"))

dat.tmp <- data.frame(
  cluster = c(1L, 2L),
  urban = c("urban", "rural"),
  LONGNUM = c(31.1, 31.9),
  LATNUM = c(-26.1, -26.9),
  admin1 = c(1L, 2L),
  admin2 = c(1L, 2L),
  admin1.char = c("admin1_1", "admin1_2"),
  admin2.char = c("admin2_1", "admin2_2"),
  admin1.name = c("North", "South"),
  admin2.name = c("A District", "B District"),
  strata = c("stale", "stale"),
  stringsAsFactors = FALSE
)

validated <- validate_mics_geospatial_admin2(
  dat.tmp,
  admin1_names = c("North", "South"),
  admin2_names = c("A District", "B District"),
  mics_file = "mock.geo.tmp.rda"
)

stopifnot(
  identical(validated$LONGNUM, dat.tmp$LONGNUM),
  identical(validated$LATNUM, dat.tmp$LATNUM),
  identical(validated$admin1, dat.tmp$admin1),
  identical(validated$admin2, dat.tmp$admin2),
  identical(validated$strata, c("1:urban", "2:rural")),
  all(validated$survey.type == "MICS")
)

bad <- dat.tmp
bad$admin2.name[2] <- "Wrong District"
err <- tryCatch(
  validate_mics_geospatial_admin2(
    bad,
    admin1_names = c("North", "South"),
    admin2_names = c("A District", "B District"),
    mics_file = "bad.geo.tmp.rda"
  ),
  error = function(condition) condition
)
stopifnot(
  inherits(err, "error"),
  grepl("Wrong District", conditionMessage(err), fixed = TRUE)
)

cat("Geospatial MICS Admin-2 fields and coordinates are preserved.\n")
