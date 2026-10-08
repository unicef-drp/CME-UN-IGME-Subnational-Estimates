source("Rcode/_supporting_scripts/dhs_download.R")

test_rdhs_user_environment_fallback <- function() {
  original_password <- Sys.getenv("RDHS_USER_PASS", unset = NA_character_)
  on.exit({
    if (is.na(original_password)) {
      Sys.unsetenv("RDHS_USER_PASS")
    } else {
      Sys.setenv(RDHS_USER_PASS = original_password)
    }
  }, add = TRUE)

  Sys.unsetenv("RDHS_USER_PASS")
  resolved <- resolve_rdhs_password(
    process_password = "",
    user_environment = list(RDHS_USER_PASS = "registry-password-string")
  )

  stopifnot(
    identical(resolved, "registry-password-string"),
    identical(Sys.getenv("RDHS_USER_PASS"), "registry-password-string")
  )
}

test_rdhs_user_environment_fallback()

scratch <- tempfile("dhs-download-")
dir.create(scratch)
year_dir <- file.path(scratch, "Nigeria", "2024")
dir.create(year_dir, recursive = TRUE)

stopifnot(identical(dhs_dataset_id("NGBR8BSV.zip"), "NGBR8BSV"))
stopifnot(identical(dhs_dataset_id("ngge8afl.zip"), "NGGE8AFL"))

br_dir <- file.path(year_dir, "NGBR8BSV")
geo_dir <- file.path(year_dir, "NGGE8AFL")
dir.create(br_dir)
dir.create(geo_dir)
invisible(file.create(file.path(br_dir, "NGBR8BFL.sav")))
invisible(file.create(file.path(geo_dir, "NGGE8AFL.shp")))

stopifnot(dhs_dataset_complete(year_dir, "NGBR8BSV.zip"))
stopifnot(dhs_dataset_complete(year_dir, "NGGE8AFL.zip"))
stopifnot(!dhs_dataset_complete(year_dir, "NGIR8BFL.zip"))

zip_dir <- file.path(scratch, "download-cache")
dir.create(zip_dir)
payload <- file.path(zip_dir, "NGBR7BFL.sav")
invisible(file.create(payload))
zip_path <- file.path(zip_dir, "NGBR7BSV.zip")
utils::zip(zipfile = zip_path, files = payload, flags = "-j")

normalized <- normalize_dhs_download(
  downloaded_paths = zip_path,
  dataset_filename = "NGBR7BSV.zip",
  year_dir = year_dir
)

stopifnot(base::file.exists(normalized$zip_path))
stopifnot(base::dir.exists(normalized$extract_dir))
stopifnot(base::file.exists(file.path(normalized$extract_dir, "NGBR7BFL.sav")))

cat("DHS download helper tests passed.\n")
