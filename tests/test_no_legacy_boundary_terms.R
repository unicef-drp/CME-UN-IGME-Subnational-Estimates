legacy_boundary_source <- paste0("ga", "dm")

all_paths <- list.files(".", recursive = TRUE, all.files = TRUE, no.. = TRUE)
all_paths <- all_paths[!grepl("^(Data|Results|outputs|tmp|[.]git|[.]Rproj[.]user)/", all_paths)]

text_extensions <- c(".R", ".Rmd", ".md", ".html", ".txt", ".csv", ".tsv", ".yml", ".yaml", ".Rproj")
text_paths <- all_paths[tolower(tools::file_ext(all_paths)) %in% sub("^[.]", "", tolower(text_extensions))]

hits <- unlist(lapply(text_paths, function(path) {
  lines <- readLines(path, warn = FALSE)
  hit_lines <- grep(legacy_boundary_source, lines, ignore.case = TRUE)
  if (length(hit_lines) == 0) {
    character(0)
  } else {
    paste0(path, ":", hit_lines, ": ", lines[hit_lines])
  }
}), use.names = FALSE)

hits <- hits[!grepl("tests/test_info_uses_georepo_paths[.]R", hits)]

if (length(hits) > 0) {
  stop("Disallowed boundary-source wording remains:\n",
       paste(hits, collapse = "\n"), call. = FALSE)
}

info_files <- list.files("Info", pattern = "_general_info[.]json$", full.names = TRUE)
info_hits <- unlist(lapply(info_files, function(info_file) {
  info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)
  flattened <- unlist(info, recursive = TRUE, use.names = TRUE)
  flattened_names <- names(flattened)
  flattened_values <- as.character(flattened)

  bad_objects <- flattened_names[
    grepl(legacy_boundary_source, flattened_names, ignore.case = TRUE)
  ]
  bad_values <- flattened_values[
    grepl(legacy_boundary_source, flattened_values, ignore.case = TRUE)
  ]
  if (length(bad_objects) == 0 && length(bad_values) == 0) {
    character(0)
  } else {
    paste0(info_file, ": ", paste(c(bad_objects, bad_values), collapse = ", "))
  }
}), use.names = FALSE)

if (length(info_hits) > 0) {
  stop("Disallowed boundary-source wording remains in Info JSON files:\n",
       paste(info_hits, collapse = "\n"), call. = FALSE)
}

cat("No disallowed boundary-source wording found in code, docs, or Info JSON files.\n")
