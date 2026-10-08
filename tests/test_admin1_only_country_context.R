source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

old_value <- Sys.getenv("BB8_ADMIN1_ONLY", unset = NA_character_)
on.exit({
  if (is.na(old_value)) {
    Sys.unsetenv("BB8_ADMIN1_ONLY")
  } else {
    Sys.setenv(BB8_ADMIN1_ONLY = old_value)
  }
}, add = TRUE)

admin2_objects <- c(
  "poly.layer.adm2", "poly.label.adm2", "poly.adm2",
  "admin2.names", "admin2.mat", "admin2.nb"
)

Sys.setenv(BB8_ADMIN1_ONLY = "1")
admin1_context <- new.env(parent = emptyenv())
for (name in admin2_objects) {
  assign(name, TRUE, envir = admin1_context)
}
load.country.info("Lesotho", envir = admin1_context, info_dir = "Info")
stopifnot(!any(vapply(admin2_objects, exists, logical(1),
                      envir = admin1_context, inherits = FALSE)))

Sys.setenv(BB8_ADMIN1_ONLY = "0")
full_context <- new.env(parent = emptyenv())
load.country.info("Lesotho", envir = full_context, info_dir = "Info")
stopifnot(
  identical(full_context$poly.layer.adm2, "georepo_LSO_2"),
  identical(full_context$poly.label.adm2, "NAME_2")
)

cat("Admin1-only country loading removes all Admin2 runtime state.\n")
