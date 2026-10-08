script <- file.path("Rcode", "12_Previous_Final_Comparison.R")
if (!file.exists(script)) {
  stop("The reusable previous-final comparison script is missing.")
}

env <- new.env(parent = globalenv())
sys.source(script, envir = env)

required_functions <- c(
  "a4_portrait_inches",
  "normalize_admin_level",
  "period_midpoint",
  "paginate_regions",
  "paginate_outcome_regions",
  "wrap_subarea_facet_label",
  "blank_unused_facet_slots",
  "draw_comparison_grob",
  "write_comparison_grobs_pdf",
  "resolve_previous_final_workbook",
  "combine_country_summary_pdfs",
  "run_country_summary_comparison_appendix",
  "load_country_survey_lookup",
  "load_country_admin_lookup",
  "apply_region_lookup",
  "prepare_previous_final_estimates",
  "prepare_direct_estimates",
  "current_admin_result_path",
  "direct_admin_result_path",
  "run_previous_final_comparison"
)
stopifnot(all(vapply(required_functions, exists, logical(1), envir = env,
                     inherits = FALSE)))

stopifnot(isTRUE(all.equal(
  unname(env$a4_portrait_inches()),
  c(210 / 25.4, 297 / 25.4)
)))

stopifnot(identical(
  env$period_midpoint(c("2000-2001", "2002-2004", "2018")),
  c(2000.5, 2003, 2018)
))

lookup_home <- file.path(tempdir(), "previous_final_lookup")
lookup_directory <- file.path(lookup_home, "Data", "Countries", "Testland")
dir.create(lookup_directory, recursive = TRUE, showWarnings = FALSE)
mod.dat <- data.frame(
  survey = c(2003, 2008, 2011),
  survey.type = c("DHS", "DHS", "MICS")
)
save(
  mod.dat,
  file = file.path(lookup_directory, "Testland_cluster_dat.rda")
)
loaded_lookup <- env$load_country_survey_lookup(
  home_dir = lookup_home,
  country = "Testland"
)
stopifnot(
  identical(loaded_lookup$survey_year, c(2003, 2008, 2011)),
  identical(loaded_lookup$survey_type, c("DHS", "DHS", "MICS"))
)

admin_lookup_home <- file.path(tempdir(), "previous_final_admin_lookup")
admin_lookup_info_dir <- file.path(admin_lookup_home, "Info")
admin_lookup_shape_dir <- file.path(
  admin_lookup_home, "Data", "shapeFiles", "test_admin_lookup"
)
dir.create(admin_lookup_info_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(admin_lookup_shape_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(
  '{"country":"Testland","poly.path":"../shapeFiles/test_admin_lookup"}',
  file.path(admin_lookup_info_dir, "Testland_general_info.json")
)
legacy_menaka <- rawToChar(as.raw(c(77, 233, 110, 97, 107, 97)))
Encoding(legacy_menaka) <- "unknown"
stopifnot(!validUTF8(legacy_menaka))
admin1.names <- data.frame(
  GeoRepo = c("North", legacy_menaka),
  Internal = c("admin1_1", "admin1_2")
)
admin2.names <- data.frame(
  GeoRepo = c("Lola", "Macenta", "N'Zerekore", "Yomou"),
  Internal = paste0("admin2_", 35:38)
)
save(
  admin1.names,
  admin2.names,
  file = file.path(admin_lookup_shape_dir, "Testland_Amat_Names.rda")
)
loaded_admin2_lookup <- env$load_country_admin_lookup(
  home_dir = admin_lookup_home,
  country = "Testland",
  admin_level = "Admin2"
)
loaded_admin1_lookup <- env$load_country_admin_lookup(
  home_dir = admin_lookup_home,
  country = "Testland",
  admin_level = "Admin1"
)
stopifnot(
  all(validUTF8(loaded_admin1_lookup$region_name)),
  identical(loaded_admin1_lookup$region_name, c("North", "M\u00e9naka")),
  identical(loaded_admin2_lookup$region, paste0("admin2_", 35:38)),
  identical(
    loaded_admin2_lookup$region_name,
    c("Lola", "Macenta", "N'Zerekore", "Yomou")
  )
)
harmonized_names <- env$apply_region_lookup(
  data.frame(
    region = c("admin2_35", "admin2_35"),
    region_name = c("Old workbook name", NA_character_),
    stringsAsFactors = FALSE
  ),
  loaded_admin2_lookup
)
stopifnot(identical(unique(harmonized_names$region_name), "Lola"))
unlink(admin_lookup_home, recursive = TRUE)

pages <- env$paginate_regions(paste0("admin1_", 1:10))
stopifnot(length(pages) == 2L, length(pages[[1]]) == 6L,
          length(pages[[2]]) == 4L)

stopifnot(
  identical(env$wrap_subarea_facet_label("Ashanti"), "Ashanti"),
  grepl(
    "\n",
    env$wrap_subarea_facet_label(
      "Bangsamoro Autonomous Region In Muslim Mindanao (BARMM)"
    ),
    fixed = TRUE
  )
)

outcome_page_data <- data.frame(
  region = c("admin2_1", "admin2_1", "admin2_145", "admin2_146"),
  outcome = c("NMR", "U5MR", "U5MR", "U5MR"),
  stringsAsFactors = FALSE
)
outcome_region_order <- c("admin2_1", "admin2_145", "admin2_146")
nmr_pages <- env$paginate_outcome_regions(
  outcome_page_data,
  outcome = "NMR",
  regions = outcome_region_order,
  regions_per_page = 2L
)
u5_pages <- env$paginate_outcome_regions(
  outcome_page_data,
  outcome = "U5MR",
  regions = outcome_region_order,
  regions_per_page = 2L
)
stopifnot(
  length(nmr_pages) == 1L,
  identical(nmr_pages[[1]], "admin2_1"),
  length(u5_pages) == 2L,
  identical(u5_pages[[2]], "admin2_146")
)

previous_raw <- data.frame(
  Country.Code = c("GHA", "GHA", "GHA", "GHA", "NGA"),
  Admin.Level = c("Admin1", "Admin1", "Admin2", "Admin2", "Admin1"),
  GADM.Region = c("Ashanti", "Ashanti", "Beyla", "Beyla", "Kano"),
  Admin1.Region = c("Ashanti", "Ashanti", "Nzerekore", "Nzerekore", "Kano"),
  Internal = c("admin1_1", "admin1_1", "admin2_29", "admin2_29",
               "admin1_1"),
  Shortind = c("NMR", "U5MR", "NMR", "U5MR", "NMR"),
  Sex = c("Total", "Total", "Total", "Total", "Total"),
  Year = c(2000.5, 2000.5, 2000.5, 2000.5, 2000.5),
  Median = c(37, 96, 55, 145, 50),
  Lower = c(31, 86, 45, 125, 40),
  Upper = c(45, 108, 65, 165, 60),
  check.names = FALSE
)
previous <- env$prepare_previous_final_estimates(previous_raw, iso3 = "GHA")
stopifnot(
  nrow(previous) == 2L,
  identical(sort(previous$outcome), c("NMR", "U5MR")),
  identical(previous$years, c(2000.5, 2000.5)),
  identical(unique(previous$region), "admin1_1"),
  identical(unique(previous$admin_level), "Admin1"),
  identical(unique(previous$source), "2023 final"),
  all(is.na(previous$survey_series))
)
previous_admin2 <- env$prepare_previous_final_estimates(
  previous_raw,
  iso3 = "GHA",
  admin_level = "Admin2"
)
stopifnot(
  nrow(previous_admin2) == 2L,
  identical(sort(previous_admin2$outcome), c("NMR", "U5MR")),
  identical(unique(previous_admin2$region), "admin2_29"),
  identical(unique(previous_admin2$region_name), "Beyla"),
  identical(unique(previous_admin2$admin_level), "Admin2")
)

stopifnot(
  identical(env$normalize_admin_level("admin-1"), "Admin1"),
  identical(env$normalize_admin_level("Admin2"), "Admin2"),
  identical(
    basename(env$current_admin_result_path(
      "Results/Testland", "Testland", "U5MR", "Admin2",
      strata_model = "unstrat", benchmarked = TRUE, all_surveys = TRUE
    )),
    "Testland_res_adm2_unstrat_u5_allsurveys_bench.rda"
  ),
  identical(
    basename(env$direct_admin_result_path(
      "Results/Testland", "Testland", "NMR", "Admin2"
    )),
    "Testland_direct_admin2_nmr.rda"
  )
)

current_raw <- data.frame(
  region = c("admin1_1", "admin1_1"),
  years = factor(c("2000", "2001")),
  median = c(0.04, 0.039),
  lower = c(0.03, 0.029),
  upper = c(0.05, 0.049)
)
current <- env$prepare_current_estimates(current_raw, outcome = "NMR")
stopifnot(
  identical(current$years, c(2000.5, 2001.5)),
  identical(current$median, c(40, 39)),
  identical(current$source, c("2026 CC", "2026 CC")),
  all(is.na(current$survey_series))
)

direct_raw <- data.frame(
  region = c("admin1_1", "admin1_1", "All"),
  years = c("2000-2001", "2002-2004", "2000-2001"),
  mean = c(0.04, 0.042, 0.05),
  lower = c(0.03, 0.032, 0.04),
  upper = c(0.05, 0.052, 0.06),
  logit.est = qlogis(c(0.04, 0.042, 0.05)),
  var.est = c(0.04, 0.09, 0.04),
  survey = c(1, 1, 1),
  surveyYears = c(2003, 2003, 2003)
)
survey_lookup <- data.frame(
  survey_year = 2003,
  survey_type = "DHS"
)
direct <- env$prepare_direct_estimates(
  direct_raw,
  outcome = "NMR",
  survey_lookup = survey_lookup
)
stopifnot(
  nrow(direct) == 2L,
  identical(direct$years, c(2000.5, 2003)),
  identical(direct$median, c(40, 42)),
  identical(direct$source, c("Survey direct", "Survey direct")),
  identical(direct$survey_id, c("1", "1")),
  identical(direct$survey_type, c("DHS", "DHS")),
  identical(direct$survey_series, c("DHS 2003", "DHS 2003")),
  isTRUE(all.equal(direct$se_logit, c(0.2, 0.3))),
  isTRUE(all.equal(
    direct$lower_1se,
    1000 * plogis(qlogis(c(0.04, 0.042)) - c(0.2, 0.3))
  )),
  isTRUE(all.equal(
    direct$upper_1se,
    1000 * plogis(qlogis(c(0.04, 0.042)) + c(0.2, 0.3))
  ))
)

model_plot_data <- rbind(
  transform(current, region_name = "Ashanti"),
  data.frame(
    region = c("admin1_1", "admin1_1"),
    outcome = c("NMR", "NMR"),
    years = c(2000, 2001),
    median = c(41, 40),
    lower = c(31, 30),
    upper = c(51, 50),
    survey_year = c(NA_real_, NA_real_),
    survey_id = c(NA_character_, NA_character_),
    survey_type = c(NA_character_, NA_character_),
    survey_series = c(NA_character_, NA_character_),
    source = c("2023 final", "2023 final"),
    region_name = c("Ashanti", "Ashanti")
  )
)
direct_plot_data <- transform(direct, region_name = "Ashanti")
comparison_plot <- env$build_previous_final_page(
  model_data = model_plot_data,
  direct_data = direct_plot_data,
  outcome = "NMR",
  regions = "admin1_1",
  country = "Testland",
  admin_level = "Admin2",
  page_number = 1L,
  page_count = 1L,
  current_label = "2026 CC",
  previous_label = "2023 final"
)
line_layers <- vapply(
  comparison_plot$layers,
  function(layer) inherits(layer$geom, "GeomLine"),
  logical(1)
)
errorbar_layers <- vapply(
  comparison_plot$layers,
  function(layer) inherits(layer$geom, "GeomErrorbar"),
  logical(1)
)
stopifnot(
  sum(line_layers) == 2L,
  sum(errorbar_layers) == 1L,
  grepl("+/- 1 SE bars", comparison_plot$labels$subtitle, fixed = TRUE)
)
stopifnot(identical(
  comparison_plot$labels$title,
  "Testland Admin-2 NMR: 2026 CC vs 2023 final"
))
current_only_plot <- env$build_previous_final_page(
  model_data = transform(current, region_name = "Ashanti"),
  direct_data = direct_plot_data,
  outcome = "NMR",
  regions = "admin1_1",
  country = "Testland",
  admin_level = "Admin1",
  page_number = 1L,
  page_count = 1L,
  current_label = "2026 CC",
  previous_label = "2023 final"
)
stopifnot(
  identical(
    current_only_plot$labels$title,
    "Testland Admin-1 NMR: 2026 CC sub-area trends"
  ),
  !grepl("2023 final| vs ", current_only_plot$labels$title),
  grepl("\n", current_only_plot$labels$subtitle, fixed = TRUE),
  identical(current_only_plot$guides$guides$linetype, "none")
)
single_direct_messages <- character()
single_direct_plot <- env$build_previous_final_page(
  model_data = transform(current, region_name = "Ashanti"),
  direct_data = direct_plot_data[1, , drop = FALSE],
  outcome = "NMR",
  regions = "admin1_1",
  country = "Testland",
  admin_level = "Admin1",
  page_number = 1L,
  page_count = 1L,
  current_label = "2026 CC",
  previous_label = "2023 final"
)
single_direct_grob <- withCallingHandlers(
  ggplot2::ggplotGrob(single_direct_plot),
  message = function(message) {
    if (grepl("Each group consists of only one observation",
              conditionMessage(message), fixed = TRUE)) {
      single_direct_messages <<- c(
        single_direct_messages,
        conditionMessage(message)
      )
    }
    invokeRestart("muffleMessage")
  }
)
stopifnot(
  inherits(single_direct_grob, "gtable"),
  length(single_direct_messages) == 0L
)
built_plot <- ggplot2::ggplot_build(comparison_plot)
stopifnot(nrow(built_plot$layout$layout) == 6L)
trained_plot <- built_plot$plot
comparison_grob <- ggplot2::ggplotGrob(comparison_plot)
blanked_grob <- env$blank_unused_facet_slots(
  comparison_grob,
  used_slots = 1L,
  panel_slots = 6L,
  ncol = 2L
)
grob_is_null <- function(grob, name) {
  index <- match(name, grob$layout$name)
  !is.na(index) && inherits(grob$grobs[[index]], "null")
}
stopifnot(
  !grob_is_null(blanked_grob, "panel-1-1"),
  grob_is_null(blanked_grob, "panel-2-1"),
  grob_is_null(blanked_grob, "panel-1-2"),
  grob_is_null(blanked_grob, "panel-2-3"),
  grob_is_null(blanked_grob, "axis-b-2-1"),
  grob_is_null(blanked_grob, "strip-t-2-1")
)
page_test_pdf <- tempfile(fileext = ".pdf")
grDevices::pdf(page_test_pdf, onefile = TRUE)
page_index <- 0L
page_index <- env$draw_comparison_grob(grid::rectGrob(), page_index)
page_index <- env$draw_comparison_grob(grid::circleGrob(), page_index)
grDevices::dev.off()
stopifnot(page_index == 2L, qpdf::pdf_length(page_test_pdf) == 2L)
unlink(page_test_pdf)

isolated_page_pdf <- tempfile(fileext = ".pdf")
isolated_page_grobs <- lapply(
  seq_len(13L),
  function(page) grid::textGrob(
    paste("Isolated comparison page", page),
    name = paste0("comparison-page-", page)
  )
)
isolated_page_path <- env$write_comparison_grobs_pdf(
  plot_grobs = isolated_page_grobs,
  output_pdf = isolated_page_pdf,
  page_size = env$a4_portrait_inches()
)
stopifnot(
  file.exists(isolated_page_path),
  qpdf::pdf_length(isolated_page_path) == 13L
)
isolated_writer_body <- paste(
  deparse(body(env$write_comparison_grobs_pdf)),
  collapse = "\n"
)
stopifnot(grepl(
  "grid::grid.newpage()",
  isolated_writer_body,
  fixed = TRUE
))
unlink(isolated_page_pdf)

explicit_previous_workbook <- tempfile(fileext = ".xlsx")
file.create(explicit_previous_workbook)
resolved_previous_workbook <- env$resolve_previous_final_workbook(
  explicit_path = explicit_previous_workbook,
  user_profile = tempdir()
)
stopifnot(identical(
  resolved_previous_workbook,
  normalizePath(explicit_previous_workbook, winslash = "/", mustWork = TRUE)
))

write_test_pdf <- function(path, pages) {
  grDevices::pdf(path, onefile = TRUE)
  for (page in seq_len(pages)) {
    graphics::plot.new()
    graphics::text(0.5, 0.5, paste("Page", page))
  }
  grDevices::dev.off()
}
core_summary_pdf <- tempfile(fileext = ".pdf")
comparison_pdf <- tempfile(fileext = ".pdf")
combined_summary_pdf <- tempfile(fileext = ".pdf")
write_test_pdf(core_summary_pdf, 1L)
write_test_pdf(comparison_pdf, 2L)
combined_path <- env$combine_country_summary_pdfs(
  core_summary_pdf,
  comparison_pdf,
  combined_summary_pdf
)
stopifnot(qpdf::pdf_length(combined_path) == 3L)
combined_path <- env$combine_country_summary_pdfs(
  core_summary_pdf,
  comparison_pdf,
  combined_summary_pdf
)
stopifnot(qpdf::pdf_length(combined_path) == 3L)
forced_locked_output <- tempfile(fileext = ".pdf")
copy_with_forced_lock <- function(from, to, overwrite = TRUE) {
  if (identical(
    normalizePath(to, winslash = "/", mustWork = FALSE),
    normalizePath(forced_locked_output, winslash = "/", mustWork = FALSE)
  )) {
    return(FALSE)
  }
  file.copy(from, to, overwrite = overwrite)
}
fallback_summary_path <- suppressWarnings(env$combine_country_summary_pdfs(
  core_summary_pdf,
  comparison_pdf,
  forced_locked_output,
  copy_file = copy_with_forced_lock
))
stopifnot(
  grepl("_with_comparison\\.pdf$", fallback_summary_path),
  qpdf::pdf_length(fallback_summary_path) == 3L
)
unlink(c(
  core_summary_pdf,
  comparison_pdf,
  combined_summary_pdf,
  fallback_summary_path
))

appendix_test_dir <- tempfile("country_summary_appendix_")
dir.create(appendix_test_dir, recursive = TRUE)
appendix_core_pdf <- file.path(appendix_test_dir, "core.pdf")
appendix_output_pdf <- file.path(appendix_test_dir, "11_CountrySummary.pdf")
write_test_pdf(appendix_core_pdf, 1L)
captured_build_dir <- NULL
captured_admin_levels <- NULL
original_comparison_runner <- env$run_previous_final_comparison
env$run_previous_final_comparison <- function(country, output_dir, ...) {
  arguments <- list(...)
  captured_build_dir <<- output_dir
  captured_admin_levels <<- arguments$admin_levels
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  comparison_path <- file.path(
    output_dir, paste0(country, "_admin_levels_current_vs_2023_final.pdf")
  )
  data_path <- file.path(
    output_dir, paste0(country, "_admin_levels_current_vs_2023_final_data.csv")
  )
  write_test_pdf(comparison_path, 2L)
  utils::write.csv(data.frame(value = 1), data_path, row.names = FALSE)
  list(pdf = comparison_path, data = data_path)
}
appendix_result <- env$run_country_summary_comparison_appendix(
  country = "Testland",
  iso3 = "TST",
  previous_workbook = explicit_previous_workbook,
  core_summary_pdf = appendix_core_pdf,
  output_summary_pdf = appendix_output_pdf,
  home_dir = appendix_test_dir,
  res_dir = appendix_test_dir,
  admin_levels = c("Admin1", "Admin2")
)
env$run_previous_final_comparison <- original_comparison_runner
standard_comparison_dir <- file.path(
  appendix_test_dir, "Figures", "PreviousFinalComparison"
)
stopifnot(
  !identical(
    normalizePath(captured_build_dir, winslash = "/", mustWork = FALSE),
    normalizePath(standard_comparison_dir, winslash = "/", mustWork = FALSE)
  ),
  identical(
    normalizePath(dirname(captured_build_dir), winslash = "/", mustWork = FALSE),
    normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
  ),
  setequal(captured_admin_levels, c("Admin1", "Admin2")),
  qpdf::pdf_length(appendix_result$summary_pdf) == 3L,
  file.exists(appendix_result$pdf),
  file.exists(appendix_result$data),
  identical(
    normalizePath(dirname(appendix_result$pdf), winslash = "/", mustWork = TRUE),
    normalizePath(standard_comparison_dir, winslash = "/", mustWork = TRUE)
  )
)

missing_appendix_dir <- tempfile("country_summary_missing_appendix_")
dir.create(missing_appendix_dir, recursive = TRUE)
missing_res_dir <- file.path(
  missing_appendix_dir, "Results", "Testland"
)
dir.create(missing_res_dir, recursive = TRUE)
missing_core_pdf <- file.path(missing_res_dir, "core.pdf")
missing_output_pdf <- file.path(
  missing_res_dir,
  "11_CountrySummary.pdf"
)
write_test_pdf(missing_core_pdf, 1L)

missing_previous_workbook <- file.path(
  missing_appendix_dir, "previous_final.xlsx"
)
unusable_previous_row <- previous_raw[1, , drop = FALSE]
unusable_previous_row[["Country.Code"]] <- "TST"
unusable_previous_row[["Admin.Level"]] <- "Admin1"
unusable_previous_row[["GADM.Region"]] <- "North"
unusable_previous_row[["Admin1.Region"]] <- "North"
unusable_previous_row[["Internal"]] <- "admin1_1"
unusable_previous_row[["Median"]] <- NA_real_
openxlsx::write.xlsx(
  rbind(previous_raw, unusable_previous_row),
  missing_previous_workbook
)

missing_cluster_dir <- file.path(
  missing_appendix_dir, "Data", "Countries", "Testland"
)
dir.create(missing_cluster_dir, recursive = TRUE)
mod.dat <- data.frame(
  survey = 2003,
  survey.type = "DHS",
  stringsAsFactors = FALSE
)
save(
  mod.dat,
  file = file.path(missing_cluster_dir, "Testland_cluster_dat.rda")
)

missing_info_dir <- file.path(missing_appendix_dir, "Info")
missing_shape_dir <- file.path(
  missing_appendix_dir, "Data", "shapeFiles", "test_current_only"
)
dir.create(missing_info_dir, recursive = TRUE)
dir.create(missing_shape_dir, recursive = TRUE)
writeLines(
  '{"country":"Testland","poly.path":"../shapeFiles/test_current_only"}',
  file.path(missing_info_dir, "Testland_general_info.json")
)
admin1.names <- data.frame(
  GeoRepo = c("North", "South"),
  Internal = c("admin1_1", "admin1_2")
)
admin2.names <- data.frame(
  GeoRepo = "North East",
  Internal = "admin2_1"
)
save(
  admin1.names,
  admin2.names,
  file = file.path(missing_shape_dir, "Testland_Amat_Names.rda")
)

write_current_only_fixture <- function(admin_level, outcome, regions) {
  current_fixture <- data.frame(
    region = rep(regions, each = 2L),
    years = rep(c(2000, 2001), times = length(regions)),
    median = rep(c(0.04, 0.038), times = length(regions)),
    lower = rep(c(0.03, 0.028), times = length(regions)),
    upper = rep(c(0.05, 0.048), times = length(regions)),
    stringsAsFactors = FALSE
  )
  current_path <- env$current_admin_result_path(
    res_dir = missing_res_dir,
    country = "Testland",
    outcome = outcome,
    admin_level = admin_level,
    strata_model = "unstrat",
    benchmarked = TRUE,
    all_surveys = TRUE
  )
  dir.create(dirname(current_path), recursive = TRUE, showWarnings = FALSE)
  save(current_fixture, file = current_path)

  direct_fixture <- data.frame(
    region = rep(regions, each = 2L),
    years = rep(c("2000-2001", "2002-2004"), times = length(regions)),
    mean = rep(c(0.041, 0.039), times = length(regions)),
    lower = rep(c(0.031, 0.029), times = length(regions)),
    upper = rep(c(0.051, 0.049), times = length(regions)),
    survey = 1,
    surveyYears = 2003,
    stringsAsFactors = FALSE
  )
  direct_path <- env$direct_admin_result_path(
    res_dir = missing_res_dir,
    country = "Testland",
    outcome = outcome,
    admin_level = admin_level
  )
  dir.create(dirname(direct_path), recursive = TRUE, showWarnings = FALSE)
  save(direct_fixture, file = direct_path)
}
for (outcome in c("NMR", "U5MR")) {
  write_current_only_fixture(
    admin_level = "Admin1",
    outcome = outcome,
    regions = c("admin1_1", "admin1_2")
  )
  write_current_only_fixture(
    admin_level = "Admin2",
    outcome = outcome,
    regions = "admin2_1"
  )
}
missing_appendix_result <- env$run_country_summary_comparison_appendix(
  country = "Testland",
  iso3 = "TST",
  previous_workbook = file.path(
    missing_appendix_dir, "deliberately_unavailable_previous_final.xlsx"
  ),
  core_summary_pdf = missing_core_pdf,
  output_summary_pdf = missing_output_pdf,
  home_dir = missing_appendix_dir,
  res_dir = missing_res_dir,
  force_current_only = TRUE
)
stopifnot(
  identical(missing_appendix_result$status, "appended_current_only")
)
missing_appendix_data <- utils::read.csv(
  missing_appendix_result$data,
  stringsAsFactors = FALSE
)
stopifnot(
  identical(missing_appendix_result$mode, "current_only"),
  identical(missing_appendix_result$admin_levels, "Admin1"),
  file.exists(missing_appendix_result$summary_pdf),
  qpdf::pdf_length(missing_appendix_result$core_summary_pdf) == 1L,
  qpdf::pdf_length(missing_appendix_result$summary_pdf) == 3L,
  grepl(
    "_admin_levels_current_subarea\\.pdf$",
    missing_appendix_result$pdf
  ),
  identical(
    basename(dirname(missing_appendix_result$pdf)),
    "CurrentSubarea"
  ),
  identical(unique(missing_appendix_data$admin_level), "Admin1"),
  "2026 CC" %in% missing_appendix_data$source,
  "Survey direct" %in% missing_appendix_data$source,
  !"2023 final" %in% missing_appendix_data$source
)

established_previous_rows <- previous_raw[1:4, , drop = FALSE]
established_previous_rows[["Country.Code"]] <- "TST"
established_previous_rows[["GADM.Region"]] <- c(
  "North", "North", "North East", "North East"
)
established_previous_rows[["Admin1.Region"]] <- c(
  "North", "North", "North", "North"
)
established_previous_rows[["Internal"]] <- c(
  "admin1_1", "admin1_1", "admin2_1", "admin2_1"
)
established_previous_workbook <- file.path(
  missing_appendix_dir,
  "established_previous_final.xlsx"
)
openxlsx::write.xlsx(
  established_previous_rows,
  established_previous_workbook
)
established_output_pdf <- file.path(
  missing_res_dir,
  "11_CountrySummary_previous_final.pdf"
)
established_appendix_result <- env$run_country_summary_comparison_appendix(
  country = "Testland",
  iso3 = "TST",
  previous_workbook = established_previous_workbook,
  core_summary_pdf = missing_core_pdf,
  output_summary_pdf = established_output_pdf,
  home_dir = missing_appendix_dir,
  res_dir = missing_res_dir
)
established_appendix_data <- utils::read.csv(
  established_appendix_result$data,
  stringsAsFactors = FALSE
)
stopifnot(
  identical(
    established_appendix_result$status,
    "appended_previous_final"
  ),
  identical(established_appendix_result$mode, "previous_final"),
  identical(established_appendix_result$admin_levels, "Admin1"),
  qpdf::pdf_length(established_appendix_result$core_summary_pdf) == 1L,
  qpdf::pdf_length(established_appendix_result$pdf) == 2L,
  qpdf::pdf_length(established_appendix_result$summary_pdf) == 3L,
  grepl(
    "_admin_levels_current_vs_2023_final\\.pdf$",
    established_appendix_result$pdf
  ),
  identical(
    basename(dirname(established_appendix_result$pdf)),
    "PreviousFinalComparison"
  ),
  setequal(
    unique(established_appendix_data$source),
    c("2026 CC", "2023 final", "Survey direct")
  )
)

# An unmatched previous-final region must not block the country summary.
# Omit the whole previous-final comparison, keep current/direct plots, and
# record the reason. Exercise both Admin-1 and Admin-2 matching failures.
for (unmatched_level in c("Admin1", "Admin2")) {
  unmatched_rows <- established_previous_rows
  unmatched_rows[["GADM.Region"]][unmatched_rows[["Admin.Level"]] == unmatched_level] <-
    "Unmatched old boundary"
  if (unmatched_level == "Admin1") {
    unmatched_rows[["Admin1.Region"]][unmatched_rows[["Admin.Level"]] == unmatched_level] <-
      "Unmatched old boundary"
  }
  unmatched_workbook <- file.path(missing_appendix_dir, paste0(unmatched_level, "_unmatched.xlsx"))
  openxlsx::write.xlsx(unmatched_rows, unmatched_workbook)
  unmatched_result <- suppressWarnings(env$run_country_summary_comparison_appendix(
    country = "Testland", iso3 = "TST", previous_workbook = unmatched_workbook,
    core_summary_pdf = missing_core_pdf,
    output_summary_pdf = file.path(missing_res_dir, paste0(unmatched_level, "_fallback.pdf")),
    home_dir = missing_appendix_dir, res_dir = missing_res_dir,
    admin_levels = c("Admin1", "Admin2")
  ))
  unmatched_data <- utils::read.csv(unmatched_result$data)
  stopifnot(identical(unmatched_result$mode, "current_only"),
    identical(unmatched_result$status, "appended_current_only"),
    grepl("Unmatched previous-final", unmatched_result$previous_final_skipped_reason, fixed = TRUE),
    !"2023 final" %in% unmatched_data$source,
    all(c("2026 CC", "Survey direct") %in% unmatched_data$source),
    setequal(unmatched_data$admin_level, c("Admin1", "Admin2")),
    qpdf::pdf_length(unmatched_result$summary_pdf) == 5L,
    file.exists(unmatched_result$status_file))
  status_record <- utils::read.csv(unmatched_result$status_file)
  stopifnot(status_record$mode == "current_only",
    identical(status_record$previous_final_skipped_reason, unmatched_result$previous_final_skipped_reason))
}
missing_workbook_error <- tryCatch(env$run_country_summary_comparison_appendix(
  country = "Testland", iso3 = "TST",
  previous_workbook = file.path(missing_appendix_dir, "missing.xlsx"),
  core_summary_pdf = missing_core_pdf, output_summary_pdf = missing_output_pdf,
  home_dir = missing_appendix_dir, res_dir = missing_res_dir
), error = identity)
stopifnot(inherits(missing_workbook_error, "error"),
  grepl("workbook does not exist", conditionMessage(missing_workbook_error)))

empty_current_fixture <- data.frame(
  region = character(),
  years = numeric(),
  median = numeric(),
  lower = numeric(),
  upper = numeric(),
  stringsAsFactors = FALSE
)
empty_admin1_nmr_path <- env$current_admin_result_path(
  res_dir = missing_res_dir,
  country = "Testland",
  outcome = "NMR",
  admin_level = "Admin1",
  strata_model = "unstrat",
  benchmarked = TRUE,
  all_surveys = TRUE
)
save(empty_current_fixture, file = empty_admin1_nmr_path)
empty_admin1_error <- tryCatch(
  env$run_previous_final_comparison(
    country = "Testland",
    iso3 = "TST",
    previous_workbook = missing_previous_workbook,
    home_dir = missing_appendix_dir,
    res_dir = missing_res_dir,
    output_dir = file.path(missing_appendix_dir, "empty_admin1_output")
  ),
  error = identity
)
stopifnot(
  inherits(empty_admin1_error, "error"),
  grepl(
    "Current Admin-1 result has no usable NMR rows:",
    conditionMessage(empty_admin1_error),
    fixed = TRUE
  )
)

write_current_only_fixture(
  admin_level = "Admin1",
  outcome = "NMR",
  regions = c("admin1_1", "admin1_2")
)
partial_admin2_nmr_path <- env$current_admin_result_path(
  res_dir = missing_res_dir,
  country = "Testland",
  outcome = "NMR",
  admin_level = "Admin2",
  strata_model = "unstrat",
  benchmarked = TRUE,
  all_surveys = TRUE
)
unlink(partial_admin2_nmr_path)
partial_admin2_result <- env$run_previous_final_comparison(
  country = "Testland",
  iso3 = "TST",
  previous_workbook = missing_previous_workbook,
  home_dir = missing_appendix_dir,
  res_dir = missing_res_dir,
  admin_levels = c("Admin1", "Admin2"),
  output_dir = file.path(missing_appendix_dir, "partial_admin2_output")
)
partial_admin2_data <- utils::read.csv(
  partial_admin2_result$data,
  stringsAsFactors = FALSE
)
stopifnot(
  identical(partial_admin2_result$mode, "current_only"),
  setequal(partial_admin2_result$admin_levels, c("Admin1", "Admin2")),
  qpdf::pdf_length(partial_admin2_result$pdf) == 3L,
  identical(
    unique(partial_admin2_data$outcome[
      partial_admin2_data$admin_level == "Admin2"
    ]),
    "U5MR"
  )
)

unlink(appendix_test_dir, recursive = TRUE)
unlink(missing_appendix_dir, recursive = TRUE)
unlink(explicit_previous_workbook)

linetype_scale <- trained_plot$scales$get_scales("linetype")
mapped_linetypes <- linetype_scale$map(
  c("2026 CC", "2023 final", "DHS 2003")
)
stopifnot(identical(
  unname(mapped_linetypes),
  c("solid", "solid", "dotted")
))
color_scale <- trained_plot$scales$get_scales("colour")
mapped_colors <- color_scale$map(
  c("2026 CC", "2023 final", "DHS 2003")
)
stopifnot(identical(
  unname(mapped_colors),
  c("#D62728", "#0072B2", "#009E73")
))

comparison_script <- paste(readLines(script, warn = FALSE), collapse = "\n")
comparison_fragments <- c(
  "survey_lookup <- load_country_survey_lookup(",
  "survey_lookup = survey_lookup",
  '"admin_level", "region", "region_name"',
  '"survey_id", "survey_type"',
  '"survey_series", "source"'
)
stopifnot(all(vapply(comparison_fragments, grepl, logical(1),
                     x = comparison_script, fixed = TRUE)))

runbook <- paste(readLines("Rcode/run_country_pipeline.R", warn = FALSE),
                 collapse = "\n")
runbook_fragments <- c(
  "Step 13: Refresh the previous-final appendix",
  "previous_final_workbook <- resolve_previous_final_workbook()",
  'project_home(), "Rcode", "12_Previous_Final_Comparison.R"',
  "regions_per_page = 6L"
)
stopifnot(all(vapply(runbook_fragments, grepl, logical(1),
                     x = runbook, fixed = TRUE)))

standard_summary_fragments <- c(
  "11_CountrySummary_core.pdf",
  "resolve_previous_final_workbook(",
  "run_country_summary_comparison_appendix("
)
stopifnot(all(vapply(standard_summary_fragments, grepl, logical(1),
                     x = runbook, fixed = TRUE)))

pipeline_runner <- paste(
  readLines("Rcode/_supporting_scripts/pipeline_runner.R", warn = FALSE),
  collapse = "\n"
)
stopifnot(all(vapply(standard_summary_fragments, grepl, logical(1),
                     x = pipeline_runner, fixed = TRUE)))
stopifnot(
  grepl("regions_per_page = 6L", pipeline_runner, fixed = TRUE),
  !grepl("regions_per_page = 4L", runbook, fixed = TRUE),
  !grepl("regions_per_page = 4L", pipeline_runner, fixed = TRUE)
)

cat("Previous-final comparison helpers pass schema and pagination checks.\n")
