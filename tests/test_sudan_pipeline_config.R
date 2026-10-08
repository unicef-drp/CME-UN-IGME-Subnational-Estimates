suppressPackageStartupMessages(library(jsonlite))

info_file <- file.path("Info", "Sudan_general_info.json")
if (!file.exists(info_file)) {
  stop("Missing Sudan pipeline configuration: ", info_file, call. = FALSE)
}
info <- fromJSON(info_file, simplifyVector = TRUE)

stopifnot(
  identical(info$country, "Sudan"),
  identical(info$iso0, "SDN"),
  identical(info$country.abbrev, "sdn"),
  identical(info$poly.layer.adm0, "georepo_SDN_0"),
  identical(info$poly.layer.adm1, "georepo_SDN_1"),
  is.null(info$poly.layer.adm2),
  identical(info$beg.year, 2000L),
  identical(info$end.proj.year, 2025L),
  identical(info$frame_year, 2008L),
  identical(as.integer(info$surveys_1frame), c(2010L, 2014L)),
  identical(info$strata_weight_source, "survey"),
  identical(info$final_model$strata.model, "strat"),
  identical(info$final_model$bench.model, "bench")
)

cat("Sudan Admin-1 pipeline configuration contract passes.\n")
