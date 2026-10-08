info_dir <- "Info"
archive_dir <- file.path(info_dir, "Archive")

stopifnot(dir.exists(info_dir), dir.exists(archive_dir))

root_entries <- list.files(
  info_dir,
  full.names = TRUE,
  recursive = FALSE,
  all.files = TRUE,
  no.. = TRUE
)
root_files <- root_entries[!file.info(root_entries)$isdir]
non_json <- root_files[tolower(tools::file_ext(root_files)) != "json"]
if (length(non_json) > 0) {
  stop(
    "Info root contains non-JSON files:\n",
    paste(basename(non_json), collapse = "\n"),
    call. = FALSE
  )
}

json_files <- list.files(
  info_dir,
  pattern = "_general_info[.]json$",
  full.names = TRUE,
  recursive = FALSE
)
stopifnot(length(json_files) == 37L)

archive_scripts <- list.files(
  archive_dir,
  pattern = "_create_info[.]R$",
  full.names = TRUE,
  recursive = FALSE
)
stopifnot(length(archive_scripts) == 37L)

archive_rdata <- list.files(
  archive_dir,
  pattern = "_general_info[.]Rdata$",
  full.names = TRUE,
  recursive = FALSE
)
stopifnot(setequal(
  basename(archive_rdata),
  c("Ethiopia_general_info.Rdata", "Nigeria_general_info.Rdata")
))

message("Info root is JSON-only; legacy country-info files are archived")
