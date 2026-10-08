helpers <- new.env(parent = globalenv())
sys.source(
  file.path("Rcode", "_supporting_scripts", "mics_admin_matching.R"),
  envir = helpers
)

if (!exists("make_optional_mics_admin_keys", envir = helpers, inherits = FALSE)) {
  stop("Missing make_optional_mics_admin_keys().")
}

poly.adm1 <- data.frame(NAME_1 = c("North", "South"))
keys <- helpers$make_optional_mics_admin_keys(
  mod.dat = NULL,
  poly.adm1 = poly.adm1,
  poly.label.adm1 = "NAME_1"
)

stopifnot(
  is.null(keys$admin2),
  identical(keys$admin1$admin1, 1:2),
  identical(keys$admin1$admin1.char, c("admin1_1", "admin1_2")),
  identical(keys$admin1$admin1.name, c("North", "South"))
)

mod.dat <- data.frame(
  admin1 = c(1L, 2L),
  admin2 = c(1L, 2L),
  admin1.char = c("admin1_1", "admin1_2"),
  admin2.char = c("admin2_1", "admin2_2"),
  admin1.name = c("North", "South"),
  admin2.name = c("North A", "South A")
)
keys <- helpers$make_optional_mics_admin_keys(
  mod.dat = mod.dat,
  poly.adm1 = poly.adm1,
  poly.label.adm1 = "NAME_1"
)

stopifnot(
  identical(keys$admin1$admin1.name, c("North", "South")),
  identical(keys$admin2$admin2.name, c("North A", "South A"))
)

step3_text <- paste(readLines(file.path("Rcode", "3_DataProcessing_sf.R")),
                    collapse = "\n")
stopifnot(
  grepl("make_optional_mics_admin_keys", step3_text, fixed = TRUE),
  grepl("!is.null(admin2.key)", step3_text, fixed = TRUE)
)

cat("MICS-only countries can initialize geospatial Admin-2 processing without DHS keys.\n")
