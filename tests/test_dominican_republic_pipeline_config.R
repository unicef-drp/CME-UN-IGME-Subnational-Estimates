info_file <- file.path(
  "Info",
  "Dominican_Republic_general_info.json"
)

stopifnot(file.exists(info_file))

info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)

source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))
dom_context <- new.env(parent = baseenv())
load.country.info(
  "Dominican_Republic",
  envir = dom_context,
  info_dir = "Info"
)

stopifnot(
  identical(info$country, "Dominican_Republic"),
  identical(info$iso0, "DOM"),
  identical(info$country.abbrev, "dom"),
  identical(info$doHIVAdj, FALSE),
  identical(info$poly.path, "../shapeFiles/georepo_DOM_shp"),
  identical(info$poly.layer.adm0, "georepo_DOM_0"),
  identical(info$poly.layer.adm1, "georepo_DOM_1"),
  identical(info$poly.layer.adm2, "georepo_DOM_2"),
  identical(info$poly.label.adm1, "NAME_1"),
  identical(info$poly.label.adm2, "NAME_2"),
  identical(as.integer(info$beg.year), 2000L),
  identical(as.integer(info$end.proj.year), 2025L),
  identical(as.integer(info$frame_year), c(2002L, 2010L)),
  identical(as.integer(info$surveys_1frame), 2013L),
  identical(as.integer(info$dhs_survey_year_start), 2007L),
  identical(as.integer(info$dhs_survey_ids), c(291L, 439L)),
  identical(info$strata_weight_source, "survey"),
  identical(info$strata.model, "unstrat"),
  identical(info$final_model$time.model, "ar1"),
  identical(info$final_model$sd.time.model, "ar1"),
  identical(info$final_model$strata.model, "unstrat"),
  identical(info$final_model$bench.model, "bench"),
  identical(
    info$info.name,
    "Dominican_Republic_general_info.json"
  ),
  identical(get("strata.model", envir = dom_context), "unstrat")
)

cat(
  "Dominican Republic uses DHS 2007/2013 with GeoRepo Admin-1/Admin-2 and ",
  "DHS 2013 as the latest-frame survey.\n",
  sep = ""
)
