source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))
source(file.path(
  "Rcode", "_supporting_scripts", "worldpop_population_inputs.R"
))

suppressPackageStartupMessages(library(terra))

write_test_raster <- function(path, value = 1) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  raster <- terra::rast(nrows = 2, ncols = 2, vals = value)
  terra::writeRaster(raster, path, overwrite = TRUE, filetype = "GTiff")
  path
}

test_root <- tempfile("worldpop-inputs-")
dir.create(test_root, recursive = TRUE)
country <- "Testland"
iso0 <- "TST"

archive_staging <- tempfile("worldpop-archive-")
archive_country_dir <- file.path(archive_staging, "2014", iso0)
dir.create(archive_country_dir, recursive = TRUE)
archive_members <- character()
for (sex in c("f", "m")) {
  for (age in 0:1) {
    filename <- sprintf(
      "tst_%s_%s_2014_constrained_1km.tif", sex, age
    )
    member <- file.path("2014", iso0, filename)
    write_test_raster(file.path(archive_staging, member), age + 1)
    archive_members <- c(archive_members, member)
  }
}

archive <- file.path(
  test_root, "Global1_2000_2020_aligned", "2014.zip"
)
dir.create(dirname(archive), recursive = TRUE)
old_dir <- getwd()
setwd(archive_staging)
utils::zip(archive, archive_members, flags = "-9Xq")
setwd(old_dir)

downloaded_urls <- character()
test_download <- function(url, destfile, ...) {
  downloaded_urls <<- c(downloaded_urls, url)
  write_test_raster(destfile, 5)
  invisible(0L)
}

manifest <- ensure_worldpop_population_inputs(
  country = country,
  iso0 = iso0,
  years = 2014:2015,
  root = test_root,
  download_file = test_download
)

stopifnot(
  nrow(manifest) == 8L,
  sum(manifest$action == "extracted") == 4L,
  sum(manifest$action == "downloaded") == 4L,
  all(vapply(manifest$path, worldpop_raster_file_ok, logical(1))),
  length(downloaded_urls) == 4L,
  all(grepl(
    "/Global_2015_2030/R2025A/2015/TST/v1/1km_ua/constrained/",
    downloaded_urls,
    fixed = TRUE
  ))
)

reuse_manifest <- ensure_worldpop_population_inputs(
  country = country,
  iso0 = iso0,
  years = 2014:2015,
  root = test_root,
  download_file = function(...) stop("Readable inputs must be reused.")
)
stopifnot(all(reuse_manifest$action == "reused"))

corrupt_target <- worldpop_population_age_sex_file(
  year = 2015,
  sex = "f",
  age = 0,
  country = country,
  iso0 = iso0,
  root = test_root
)
writeLines("not a raster", corrupt_target)
replacement_manifest <- ensure_worldpop_population_inputs(
  country = country,
  iso0 = iso0,
  years = 2015,
  root = test_root,
  download_file = test_download
)
stopifnot(
  sum(replacement_manifest$action == "downloaded") == 1L,
  sum(replacement_manifest$action == "reused") == 3L,
  worldpop_raster_file_ok(corrupt_target)
)

missing_archive_root <- tempfile("worldpop-missing-archive-")
missing_archive <- try(
  ensure_worldpop_population_inputs(
    country = country,
    iso0 = iso0,
    years = 2013,
    root = missing_archive_root,
    download_file = test_download
  ),
  silent = TRUE
)
stopifnot(
  inherits(missing_archive, "try-error"),
  grepl("Missing WorldPop Global1 archive", missing_archive, fixed = TRUE)
)

failed_download_root <- tempfile("worldpop-failed-download-")
failed_download <- try(
  ensure_worldpop_population_inputs(
    country = country,
    iso0 = iso0,
    years = 2015,
    root = failed_download_root,
    download_file = function(url, destfile, ...) {
      dir.create(dirname(destfile), recursive = TRUE, showWarnings = FALSE)
      writeLines("not a raster", destfile)
      invisible(0L)
    }
  ),
  silent = TRUE
)
failed_download_dir <- file.path(
  failed_download_root, "Global2_2015_2030", country
)
stopifnot(
  inherits(failed_download, "try-error"),
  grepl("Downloaded WorldPop raster is unreadable", failed_download,
        fixed = TRUE),
  length(list.files(failed_download_dir, pattern = "[.]download$")) == 0L
)

nonzero_target <- file.path(
  tempfile("worldpop-nonzero-status-"), "downloaded.tif"
)
nonzero_download <- try(
  download_worldpop_raster(
    url = "https://example.test/nonzero.tif",
    target = nonzero_target,
    download_file = function(url, destfile, ...) {
      write_test_raster(destfile, 7)
      invisible(7L)
    }
  ),
  silent = TRUE
)
stopifnot(
  inherits(nonzero_download, "try-error"),
  grepl("status 7", nonzero_download, fixed = TRUE),
  !file.exists(nonzero_target)
)

old_timeout <- getOption("timeout")
on.exit(options(timeout = old_timeout), add = TRUE)
options(timeout = 13)
observed_timeout <- NA_real_
timeout_target <- file.path(
  tempfile("worldpop-download-timeout-"), "downloaded.tif"
)
download_worldpop_raster(
  url = "https://example.test/timeout.tif",
  target = timeout_target,
  download_file = function(url, destfile, ...) {
    observed_timeout <<- getOption("timeout")
    write_test_raster(destfile, 8)
    invisible(0L)
  }
)
stopifnot(
  observed_timeout >= 200000,
  identical(getOption("timeout"), 13),
  worldpop_raster_file_ok(timeout_target)
)

admin_script <- paste(
  readLines(file.path("Rcode", "5_Admin_Weights_sf.R"), warn = FALSE),
  collapse = "\n"
)
stopifnot(
  grepl("worldpop_population_inputs.R", admin_script, fixed = TRUE),
  grepl("ensure_worldpop_population_inputs(", admin_script, fixed = TRUE)
)

cat("WorldPop inputs are reused, extracted, or downloaded conditionally.\n")
