rmd_file <- file.path("Rcode", "11_CountrySummary.Rmd")

if (!file.exists(rmd_file)) {
  stop("Missing country summary source: ", rmd_file)
}

lines <- readLines(rmd_file, warn = FALSE)
section_start <- grep("^## Admin 1 Figures$", lines)
section_end <- grep("^adm1.nmr.PD.filename <-", lines)

if (length(section_start) != 1L || length(section_end) != 1L ||
    section_end <= section_start) {
  stop("Could not isolate the Admin-1 median-map figure block.")
}

median_map_block <- lines[section_start:(section_end - 1L)]

if (any(grepl("hfill", median_map_block, fixed = TRUE))) {
  stop("Admin-1 stacked median maps must not use hfill alignment.")
}

if (!any(grepl("[1em]", median_map_block, fixed = TRUE))) {
  stop("Admin-1 stacked median maps need an explicit centered vertical gap.")
}

message("Admin-1 NMR and U5MR median maps use one centered vertical stack.")
