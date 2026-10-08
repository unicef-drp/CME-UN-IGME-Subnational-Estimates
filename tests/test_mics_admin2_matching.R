source(file.path("Rcode", "_supporting_scripts", "mics_admin_matching.R"))

mod.dat <- data.frame(
  admin1 = c(1, 1, 2),
  admin2 = c(10, 10, 20),
  admin1.char = c("admin1_1", "admin1_1", "admin1_2"),
  admin2.char = c("admin2_10", "admin2_10", "admin2_20"),
  admin1.name = c("North", "North", "South"),
  admin2.name = c("A District", "A District", "B District"),
  strata = c("10:urban", "10:rural", "20:urban"),
  stringsAsFactors = FALSE
)

admin.key <- make_mics_admin2_key(mod.dat)

if (nrow(admin.key) != 2) {
  stop("Admin2 key should have one row per admin2.name, not one row per DHS stratum.")
}

if ("strata" %in% names(admin.key)) {
  stop("Admin2 key should not include strata because that makes admin2.name non-unique.")
}

dat.tmp <- data.frame(
  cluster = c(1, 2),
  age = c("0", "1-11"),
  years = c(2019, 2019),
  total = c(1, 2),
  Y = c(0, 1),
  v005 = c(1000000, 1000000),
  urban = factor(c("urban", "rural")),
  admin2.name = factor(c("A District", "B District")),
  survey = c(2019, 2019),
  stringsAsFactors = FALSE
)

matched <- attach_mics_admin2_key(dat.tmp, admin.key, mics_file = "mock.tmp.rda")

expected_cols <- c("admin1", "admin2", "admin1.char", "admin2.char",
                   "admin1.name", "strata", "LONGNUM", "LATNUM",
                   "survey.type")
missing_cols <- setdiff(expected_cols, names(matched))
if (length(missing_cols) > 0) {
  stop("Matched MICS data is missing expected columns: ",
       paste(missing_cols, collapse = ", "))
}

if (!identical(matched$admin1, c(1, 2)) ||
    !identical(matched$admin2, c(10, 20)) ||
    !identical(matched$admin1.name, c("North", "South"))) {
  stop("MICS admin2 matching did not copy the expected admin IDs and names.")
}

if (!identical(matched$strata, c("10:urban", "20:rural"))) {
  stop("MICS strata should be derived deterministically from admin2 and urban.")
}

unmatched <- dat.tmp
unmatched$admin2.name <- as.character(unmatched$admin2.name)
unmatched$admin2.name[2] <- "Missing District"
err <- tryCatch(
  attach_mics_admin2_key(unmatched, admin.key, mics_file = "mock.tmp.rda"),
  error = function(e) e
)
if (!inherits(err, "error") ||
    !grepl("Missing District", conditionMessage(err), fixed = TRUE)) {
  stop("Unmatched MICS admin2 names should fail loudly with the missing names.")
}

cat("MICS admin2 matching validates unique keys and unmatched names.\n")
