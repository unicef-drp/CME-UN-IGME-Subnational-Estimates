source(file.path("Rcode", "_supporting_scripts", "mics_admin_matching.R"))

mod.dat <- data.frame(
  admin1 = c(1, 2),
  admin1.char = c("admin1_1", "admin1_2"),
  admin1.name = c("Analamanga", "Alaotra-Mangoro"),
  stringsAsFactors = FALSE
)

admin1.key <- make_mics_admin1_key(mod.dat)

dat.tmp <- data.frame(
  cluster = c(101, 102),
  age = c("0", "1-11"),
  years = c(2018, 2018),
  total = c(5, 6),
  Y = c(0, 1),
  v005 = c(0.5, 0.7),
  urban = c("urban", "rural"),
  admin1.name = c("Analamanga", "Alaotra-Mangoro"),
  survey = c(2018, 2018),
  stringsAsFactors = FALSE
)

matched <- attach_mics_admin1_key(dat.tmp, admin1.key, "Madagascar MICS")

stopifnot(identical(matched$admin1, c(1, 2)))
stopifnot(identical(matched$admin1.char, c("admin1_1", "admin1_2")))
stopifnot(identical(matched$strata, c("1:urban", "2:rural")))
stopifnot(all(is.na(matched$admin2)))
stopifnot(all(is.na(matched$admin2.char)))
stopifnot(all(is.na(matched$admin2.name)))
stopifnot(identical(matched$survey.type, c("MICS", "MICS")))

cat("MICS admin-1 fallback attaches admin-1 metadata and leaves admin-2 empty.\n")
