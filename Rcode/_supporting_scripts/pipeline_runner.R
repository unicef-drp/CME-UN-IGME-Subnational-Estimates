`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

pipeline_project_dir <- function(project_dir = NULL) {
  if (is.null(project_dir) || !nzchar(project_dir)) {
    project_dir <- Sys.getenv("UN_SUBNATIONAL_HOME", unset = getwd())
  }
  normalizePath(project_dir, winslash = "/", mustWork = FALSE)
}

pipeline_timestamp <- function(time = Sys.time()) {
  format(time, "%Y%m%d_%H%M%S")
}

pipeline_time_iso <- function(time = Sys.time()) {
  format(time, "%Y-%m-%dT%H:%M:%S%z")
}

pipeline_pandoc_dirs <- function() {
  pandoc_on_path <- Sys.which("pandoc")
  existing <- Sys.getenv("RSTUDIO_PANDOC", unset = "")
  program_files <- Sys.getenv("ProgramFiles", unset = "")
  local_app_data <- Sys.getenv("LOCALAPPDATA", unset = "")

  unique(Filter(nzchar, c(
    existing,
    if (nzchar(pandoc_on_path)) dirname(pandoc_on_path) else "",
    if (nzchar(program_files)) {
      file.path(program_files, "RStudio", "resources", "app", "bin",
                "quarto", "bin", "tools")
    } else "",
    if (nzchar(program_files)) {
      file.path(program_files, "Quarto", "bin", "tools")
    } else "",
    if (nzchar(local_app_data)) {
      file.path(local_app_data, "Programs", "RStudio", "resources", "app",
                "bin", "quarto", "bin", "tools")
    } else "",
    if (nzchar(local_app_data)) {
      file.path(local_app_data, "Programs", "Quarto", "bin", "tools")
    } else "",
    "/Applications/RStudio.app/Contents/Resources/app/bin/quarto/bin/tools",
    "/usr/lib/rstudio/resources/app/bin/quarto/bin/tools",
    "/usr/lib/rstudio/bin/pandoc"
  )))
}

configure_pipeline_pandoc <- function(candidates = pipeline_pandoc_dirs()) {
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    return(FALSE)
  }
  if (rmarkdown::pandoc_available()) {
    return(TRUE)
  }

  executable <- if (.Platform$OS.type == "windows") "pandoc.exe" else "pandoc"
  for (candidate in candidates) {
    candidate <- normalizePath(candidate, winslash = "/", mustWork = FALSE)
    candidate_executable <- if (basename(candidate) == executable) {
      candidate
    } else {
      file.path(candidate, executable)
    }
    if (!file.exists(candidate_executable)) {
      next
    }
    pandoc_dir <- dirname(candidate_executable)
    Sys.setenv(RSTUDIO_PANDOC = pandoc_dir)
    rmarkdown::find_pandoc(cache = FALSE)
    if (rmarkdown::pandoc_available()) {
      return(TRUE)
    }
  }
  FALSE
}

pipeline_quarto_paths <- function() {
  quarto_on_path <- Sys.which("quarto")
  program_files <- Sys.getenv("ProgramFiles", unset = "")
  local_app_data <- Sys.getenv("LOCALAPPDATA", unset = "")
  executable <- if (.Platform$OS.type == "windows") "quarto.exe" else "quarto"

  unique(Filter(nzchar, c(
    quarto_on_path,
    if (nzchar(program_files)) {
      file.path(program_files, "RStudio", "resources", "app", "bin",
                "quarto", "bin", executable)
    } else "",
    if (nzchar(program_files)) {
      file.path(program_files, "Quarto", "bin", executable)
    } else "",
    if (nzchar(local_app_data)) {
      file.path(local_app_data, "Programs", "RStudio", "resources", "app",
                "bin", "quarto", "bin", executable)
    } else "",
    if (nzchar(local_app_data)) {
      file.path(local_app_data, "Programs", "Quarto", "bin", executable)
    } else "",
    file.path(
      "/Applications/RStudio.app/Contents/Resources/app/bin/quarto/bin",
      executable
    ),
    file.path("/usr/lib/rstudio/resources/app/bin/quarto/bin", executable),
    file.path("/usr/local/bin", executable),
    file.path("/usr/bin", executable)
  )))
}

find_pipeline_quarto <- function(candidates = pipeline_quarto_paths()) {
  for (candidate in candidates) {
    candidate <- normalizePath(candidate, winslash = "/", mustWork = FALSE)
    if (file.exists(candidate)) {
      return(candidate)
    }
  }
  ""
}

normalize_pipeline_mode <- function(mode) {
  mode <- tolower(trimws(as.character(mode)[1]))
  if (!mode %in% c("preview", "production")) {
    stop("Pipeline mode must be 'preview' or 'production'.", call. = FALSE)
  }
  mode
}

country_report_display_name <- function(country) {
  if (length(country) != 1L || is.na(country) || !nzchar(as.character(country))) {
    stop("Country must be one non-empty value.", call. = FALSE)
  }
  country <- as.character(country)
  if (identical(country, "Cote_dIvoire")) {
    return("Cote d'Ivoire")
  }
  gsub("_", " ", country, fixed = TRUE)
}

normalize_report_year <- function(report_year = 2026L) {
  valid <- length(report_year) == 1L &&
    !is.na(report_year) &&
    grepl("^[0-9]{4}$", as.character(report_year))
  value <- suppressWarnings(as.numeric(report_year))
  valid <- valid && is.finite(value) && value == floor(value) &&
    value >= 2000 && value <= 2999
  if (!valid) {
    stop(
      "Report year must be one four-digit year from 2000 through 2999.",
      call. = FALSE
    )
  }
  as.integer(value)
}

country_report_filename <- function(country, report_year = 2026L) {
  paste0(
    country_report_display_name(country),
    " Report ",
    normalize_report_year(report_year),
    ".pdf"
  )
}

parse_pipeline_args <- function(args = commandArgs(trailingOnly = TRUE),
                                country = "",
                                mode = Sys.getenv("UN_SUBNATIONAL_MODE", unset = "preview"),
                                render_summary = TRUE,
                                report_year = 2026L) {
  help <- FALSE

  next_arg <- function(i, flag) {
    if (i >= length(args)) {
      stop("Missing value after ", flag, ".", call. = FALSE)
    }
    args[[i + 1L]]
  }

  i <- 1L
  while (i <= length(args)) {
    arg <- args[[i]]

    if (arg %in% c("--help", "-h")) {
      help <- TRUE
    } else if (arg == "--country") {
      country <- next_arg(i, arg)
      i <- i + 1L
    } else if (grepl("^--country=", arg)) {
      country <- sub("^--country=", "", arg)
    } else if (arg == "--mode") {
      mode <- next_arg(i, arg)
      i <- i + 1L
    } else if (grepl("^--mode=", arg)) {
      mode <- sub("^--mode=", "", arg)
    } else if (arg == "--preview") {
      mode <- "preview"
    } else if (arg == "--production") {
      mode <- "production"
    } else if (arg == "--report-year") {
      report_year <- next_arg(i, arg)
      i <- i + 1L
    } else if (grepl("^--report-year=", arg)) {
      report_year <- sub("^--report-year=", "", arg)
    } else if (arg %in% c("--skip-summary", "--no-summary")) {
      render_summary <- FALSE
    } else if (arg == "--summary") {
      render_summary <- TRUE
    } else if (!startsWith(arg, "-")) {
      country <- arg
    } else {
      stop("Unknown pipeline argument: ", arg, call. = FALSE)
    }
    i <- i + 1L
  }

  if (!isTRUE(help) && (is.null(country) || !nzchar(country))) {
    stop(
      "Set country in Rcode/run_country_pipeline.R or provide --country COUNTRY.",
      call. = FALSE
    )
  }

  list(
    country = country,
    mode = normalize_pipeline_mode(mode),
    render_summary = isTRUE(render_summary),
    report_year = normalize_report_year(report_year),
    help = help
  )
}

pipeline_checkpoint <- function(label, mode = "preview", prompt = readline) {
  mode <- normalize_pipeline_mode(mode)
  if (mode == "production") {
    return(TRUE)
  }

  answer <- prompt(paste0("\n[preview] ", label, "\nContinue? [y/N]: "))
  tolower(trimws(answer)) %in% c("y", "yes")
}

pipeline_step <- function(id,
                          label,
                          script,
                          kind = "source",
                          env = character(),
                          optional = FALSE,
                          review = FALSE,
                          review_label = NULL,
                          skip_if = NULL) {
  list(
    id = id,
    label = label,
    script = script,
    kind = kind,
    env = env,
    optional = optional,
    review = review,
    review_label = review_label %||% paste("Review", label),
    skip_if = skip_if
  )
}

make_pipeline_setup_steps <- function(country, project_dir = pipeline_project_dir()) {
  list(
    pipeline_step(
      "preparation",
      paste("Load", country, "JSON context and create folders"),
      file.path(project_dir, "Rcode", "1_Preperation.R"),
      kind = "context_source"
    )
  )
}

has_frame_year <- function(info) {
  exists("frame_year", envir = info, inherits = TRUE) &&
    length(get("frame_year", envir = info, inherits = TRUE)) > 0 &&
    any(!is.na(get("frame_year", envir = info, inherits = TRUE)))
}

uses_survey_strata_weights <- function(info) {
  if (!exists("strata_weight_source", envir = info, inherits = TRUE)) {
    return(FALSE)
  }
  source <- get("strata_weight_source", envir = info, inherits = TRUE)
  length(source) > 0 && tolower(as.character(source)[1]) == "survey"
}

make_pipeline_steps <- function(country,
                                info,
                                project_dir = pipeline_project_dir(),
                                render_summary = TRUE) {
  rcode <- file.path(project_dir, "Rcode")
  final_review_label <-
    "Inspect final data, plots, dashboard, and summary PDF; summarize any issues"
  steps <- list(
    pipeline_step(
      "georepo_boundaries",
      "Download and normalize GeoRepo boundaries",
      file.path(rcode, "2_download_georepo_shapefiles.R"),
      kind = "source_main",
      skip_if = georepo_boundaries_available
    ),
    pipeline_step(
      "data_processing",
      "Process survey microdata",
      file.path(rcode, "3_DataProcessing_sf.R")
    ),
    pipeline_step(
      "direct_smoothed_direct",
      "Run direct and smoothed-direct estimates",
      file.path(rcode, "4_Direct_SmoothDirect_sf.R")
    ),
    pipeline_step(
      "admin_weights",
      "Prepare admin population weights",
      file.path(rcode, "5_Admin_Weights_sf.R")
    ),
    pipeline_step(
      "pre_bb8_comparison",
      "Generate pre-BB8 comparison plots",
      file.path(rcode, "6_Comparison_Plot.R"),
      review = TRUE,
      review_label = "Review pre-BB8 comparison plots"
    )
  )

  if (has_frame_year(info) && !uses_survey_strata_weights(info)) {
    steps <- c(
      steps,
      list(
        pipeline_step(
          "ur_prop",
          "Estimate urban/rural proportions",
          file.path(rcode, "7a_UR_prop.R")
        ),
        pipeline_step(
          "ur_thresholding",
          "Apply urban/rural thresholding",
          file.path(rcode, "7b_UR_thresholding_sf.R")
        )
      )
    )
  }

  steps <- c(
    steps,
    list(
      pipeline_step(
        "bb8",
        "Run BB8 model",
        file.path(rcode, "8_10_BB8.R")
      )
    )
  )

  admin1_benchmarks <- file.path(rcode, "8_10_Run_Unstrat_Admin1_Benchmarks.R")
  if (file.exists(admin1_benchmarks)) {
    steps <- c(
      steps,
      list(
        pipeline_step(
          "admin1_unstrat_benchmarks",
          "Backfill Admin-1 benchmarks only when unstratified is selected",
          admin1_benchmarks
        )
      )
    )
  }

  steps <- c(
    steps,
    list(
      pipeline_step(
        "bb8_comparison",
        "Generate BB8 comparison plots",
        file.path(rcode, "9_Comparison_Plot.R"),
        review = TRUE,
        review_label = "Review BB8 comparison plots"
      ),
      pipeline_step(
        "diagnostics",
        "Generate diagnostic plots",
        file.path(rcode, "9_Diagnostic_Plots.R")
      ),
      pipeline_step(
        "report_plots",
        "Generate report plots",
        file.path(rcode, "11_Report_Plot.R")
      )
    )
  )

  if (isTRUE(render_summary)) {
    steps <- c(
      steps,
      list(
        pipeline_step(
          "country_summary",
          "Render country summary PDF",
          file.path(rcode, "11_CountrySummary.Rmd"),
          kind = "render_rmd",
          review = TRUE,
          review_label = final_review_label
        )
      )
    )
  } else {
    final_step_index <- length(steps)
    steps[[final_step_index]]$review <- TRUE
    steps[[final_step_index]]$review_label <- final_review_label
  }

  steps
}

georepo_boundaries_available <- function(context) {
  needed <- c("poly.path", "poly.layer.adm0", "poly.layer.adm1")
  if (!all(vapply(needed, exists, logical(1), envir = context, inherits = TRUE))) {
    return(FALSE)
  }

  poly_path <- get("poly.path", envir = context, inherits = TRUE)
  layers <- c(
    get("poly.layer.adm0", envir = context, inherits = TRUE),
    get("poly.layer.adm1", envir = context, inherits = TRUE)
  )
  if (exists("poly.layer.adm2", envir = context, inherits = TRUE)) {
    adm2 <- get("poly.layer.adm2", envir = context, inherits = TRUE)
    if (!is.null(adm2) && nzchar(as.character(adm2)[1])) {
      layers <- c(layers, adm2)
    }
  }

  all(file.exists(file.path(poly_path, paste0(layers, ".shp"))))
}

should_skip_pipeline_step <- function(step, context) {
  skip_if <- step$skip_if
  if (is.null(skip_if)) {
    return(list(skip = FALSE, reason = NULL))
  }

  skipped <- FALSE
  if (is.function(skip_if)) {
    skipped <- isTRUE(skip_if(context))
  } else if (identical(skip_if, "georepo_boundaries_available")) {
    skipped <- georepo_boundaries_available(context)
  }

  list(
    skip = skipped,
    reason = if (skipped) "Required outputs are already available." else NULL
  )
}

restore_env <- function(old_values) {
  for (env_name in names(old_values)) {
    if (is.na(old_values[[env_name]])) {
      Sys.unsetenv(env_name)
    } else {
      do.call(Sys.setenv, setNames(as.list(old_values[[env_name]]), env_name))
    }
  }
  invisible(TRUE)
}

with_step_env <- function(values, expr) {
  if (is.null(values) || length(values) == 0) {
    force(expr)
    return(invisible(NULL))
  }

  old <- setNames(Sys.getenv(names(values), unset = NA_character_), names(values))
  on.exit(restore_env(old), add = TRUE)
  do.call(Sys.setenv, as.list(values))
  force(expr)
  invisible(NULL)
}

pipeline_run_with_log <- function(expr, log_file) {
  dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)
  conn <- file(log_file, open = "at")
  output_sinks <- sink.number(type = "output")
  message_sinks <- sink.number(type = "message")
  sink(conn, type = "output", split = TRUE)
  sink(conn, type = "message")
  on.exit({
    while (sink.number(type = "message") > message_sinks) {
      sink(type = "message")
    }
    while (sink.number(type = "output") > output_sinks) {
      sink(type = "output")
    }
    close(conn)
  }, add = TRUE)

  force(expr)
}

source_pipeline_script <- function(step, context) {
  script <- normalizePath(step$script, winslash = "/", mustWork = FALSE)
  if (!file.exists(script)) {
    if (isTRUE(step$optional)) {
      return(invisible(NULL))
    }
    stop("Script not found: ", script, call. = FALSE)
  }

  if (identical(step$kind, "isolated_source")) {
    isolated_env <- new.env(parent = globalenv())
    if (exists("country", envir = context, inherits = TRUE)) {
      isolated_env$country <- get("country", envir = context, inherits = TRUE)
    }
    source(script, local = isolated_env, echo = FALSE)
  } else if (identical(step$kind, "context_source")) {
    source(script, local = context, echo = FALSE)
  } else if (identical(step$kind, "source_main")) {
    step_env <- new.env(parent = context)
    source(script, local = step_env, echo = FALSE)
    if (!exists("main", envir = step_env, inherits = FALSE) ||
        !is.function(get("main", envir = step_env, inherits = FALSE))) {
      stop("Script does not define main(): ", script, call. = FALSE)
    }
    get("main", envir = step_env, inherits = FALSE)()
  } else if (identical(step$kind, "render_rmd")) {
    if (!requireNamespace("rmarkdown", quietly = TRUE)) {
      stop("Package 'rmarkdown' is required to render ", script, call. = FALSE)
    }
    if (!configure_pipeline_pandoc()) {
      stop(
        "Pandoc is required to render ", script,
        ". Install Pandoc/Quarto or set RSTUDIO_PANDOC to its directory.",
        call. = FALSE
      )
    }
    country <- get("country", envir = context, inherits = TRUE)
    project_dir <- get("project_dir", envir = context, inherits = TRUE)
    report_year <- get("report_year", envir = context, inherits = TRUE)
    output_dir <- file.path(project_dir, "Results", country)
    summary_build_dir <- file.path(output_dir, "Figures", "Summary")
    dir.create(summary_build_dir, recursive = TRUE, showWarnings = FALSE)
    core_summary_pdf <- file.path(
      summary_build_dir, "11_CountrySummary_core.pdf"
    )
    output_summary_pdf <- file.path(
      output_dir,
      country_report_filename(country, report_year)
    )
    rmarkdown::render(
      input = script,
      output_file = basename(core_summary_pdf),
      output_dir = dirname(core_summary_pdf),
      envir = context,
      quiet = FALSE
    )
    comparison_env <- new.env(parent = context)
    sys.source(
      file.path(project_dir, "Rcode", "12_Previous_Final_Comparison.R"),
      envir = comparison_env
    )
    previous_final_workbook <- comparison_env$resolve_previous_final_workbook()
    final_model <- get("final_model", envir = context, inherits = TRUE)
    comparison_env$run_country_summary_comparison_appendix(
      country = country,
      iso3 = get("iso0", envir = context, inherits = TRUE),
      previous_workbook = previous_final_workbook,
      core_summary_pdf = core_summary_pdf,
      output_summary_pdf = output_summary_pdf,
      home_dir = project_dir,
      res_dir = output_dir,
      regions_per_page = 6L,
      strata_model = final_model$strata.model,
      benchmarked = identical(final_model$bench.model, "bench"),
      all_surveys = identical(final_model$strata.model, "unstrat")
    )
  } else {
    step_env <- new.env(parent = context)
    source(script, local = step_env, echo = FALSE)
  }

  invisible(NULL)
}

run_pipeline_step <- function(step,
                              step_index,
                              context,
                              mode,
                              log_dir,
                              prompt = readline) {
  mode <- normalize_pipeline_mode(mode)
  safe_id <- gsub("[^A-Za-z0-9_]+", "_", step$id)
  log_file <- file.path(log_dir, sprintf("%02d_%s.log", step_index, safe_id))
  script <- normalizePath(step$script, winslash = "/", mustWork = FALSE)

  skip <- should_skip_pipeline_step(step, context)
  if (isTRUE(skip$skip)) {
    message("Skipping: ", step$label, " (", skip$reason, ")")
    return(list(
      step_index = step_index,
      step_id = step$id,
      label = step$label,
      script = script,
      status = "skipped",
      reason = skip$reason,
      log_file = log_file,
      review_label = step$review_label
    ))
  }

  started <- Sys.time()
  message("\nStep: ", step$label)
  message("Script: ", script)
  message("Started: ", format(started, "%Y-%m-%d %H:%M:%S %Z"))

  old_wd <- getwd()
  if (exists("project_dir", envir = context, inherits = TRUE)) {
    setwd(get("project_dir", envir = context, inherits = TRUE))
    on.exit(setwd(old_wd), add = TRUE)
  }

  result <- tryCatch(
    {
      with_step_env(step$env, {
        pipeline_run_with_log({
          source_pipeline_script(step, context)
        }, log_file)
      })
      list(ok = TRUE, error = NULL)
    },
    error = function(e) {
      list(ok = FALSE, error = conditionMessage(e))
    }
  )

  completed <- Sys.time()
  elapsed <- as.numeric(difftime(completed, started, units = "secs"))

  record <- list(
    step_index = step_index,
    step_id = step$id,
    label = step$label,
    script = script,
    status = if (isTRUE(result$ok)) "completed" else "failed",
    started_at = pipeline_time_iso(started),
    completed_at = pipeline_time_iso(completed),
    elapsed_seconds = elapsed,
    log_file = log_file,
    review_label = step$review_label
  )

  if (!isTRUE(result$ok)) {
    record$error <- result$error
    return(record)
  }

  if (isTRUE(step$review) && mode == "preview") {
    continue <- pipeline_checkpoint(step$review_label, mode = mode, prompt = prompt)
    if (!isTRUE(continue)) {
      record$status <- "review_pending"
      record$reason <- paste("Stopped at preview review checkpoint:", step$review_label)
    }
  }

  record
}

json_escape <- function(x) {
  x <- gsub("\\\\", "\\\\\\\\", x)
  x <- gsub('"', '\\\\"', x)
  x <- gsub("\n", "\\\\n", x, fixed = TRUE)
  x <- gsub("\r", "\\\\r", x, fixed = TRUE)
  x <- gsub("\t", "\\\\t", x, fixed = TRUE)
  x
}

to_json <- function(x, indent = 0L) {
  pad <- paste(rep(" ", indent), collapse = "")
  child_pad <- paste(rep(" ", indent + 2L), collapse = "")

  if (is.null(x)) {
    return("null")
  }
  if (is.character(x)) {
    if (length(x) == 0) return("[]")
    return(if (length(x) == 1) {
      paste0('"', json_escape(x), '"')
    } else {
      paste0("[", paste(vapply(x, to_json, character(1), indent = indent + 2L),
                        collapse = ", "), "]")
    })
  }
  if (is.logical(x)) {
    if (length(x) == 0) return("[]")
    return(ifelse(is.na(x), "null", ifelse(x, "true", "false"))[1])
  }
  if (is.numeric(x) || is.integer(x)) {
    if (length(x) == 0 || is.na(x[1]) || !is.finite(x[1])) {
      return("null")
    }
    return(as.character(x[1]))
  }
  if (is.list(x)) {
    if (length(x) == 0) {
      return(if (is.null(names(x))) "[]" else "{}")
    }
    nms <- names(x)
    if (is.null(nms) || all(!nzchar(nms))) {
      values <- vapply(x, to_json, character(1), indent = indent + 2L)
      return(paste0("[\n", child_pad, paste(values, collapse = paste0(",\n", child_pad)),
                    "\n", pad, "]"))
    }
    values <- vapply(seq_along(x), function(i) {
      paste0('"', json_escape(nms[[i]]), '": ', to_json(x[[i]], indent + 2L))
    }, character(1))
    return(paste0("{\n", child_pad, paste(values, collapse = paste0(",\n", child_pad)),
                  "\n", pad, "}"))
  }
  paste0('"', json_escape(as.character(x)[1]), '"')
}

write_pipeline_manifest <- function(manifest, manifest_file) {
  dir.create(dirname(manifest_file), recursive = TRUE, showWarnings = FALSE)
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::write_json(manifest, manifest_file, auto_unbox = TRUE, pretty = TRUE, null = "null")
  } else {
    writeLines(to_json(manifest), manifest_file, useBytes = TRUE)
  }
  invisible(manifest_file)
}

pipeline_timing_columns <- function() {
  c(
    "country", "mode", "run_status", "step_index", "step_id", "label", "script",
    "status", "started_at", "completed_at", "elapsed_minutes", "log_file",
    "reason", "error", "review_label"
  )
}

step_value <- function(step, name, default = NA) {
  value <- step[[name]]
  if (is.null(value) || length(value) == 0) {
    return(default)
  }
  value[[1]]
}

pipeline_timing_data <- function(manifest) {
  columns <- pipeline_timing_columns()
  steps <- manifest$steps %||% list()
  if (length(steps) == 0) {
    empty <- as.data.frame(setNames(replicate(length(columns), logical(0), simplify = FALSE), columns))
    return(empty)
  }

  rows <- lapply(steps, function(step) {
    elapsed_seconds <- step_value(step, "elapsed_seconds", NA_real_)
    elapsed_minutes <- if (is.na(elapsed_seconds)) NA_real_ else round(as.numeric(elapsed_seconds) / 60, 4)
    data.frame(
      country = manifest$country %||% NA_character_,
      mode = manifest$mode %||% NA_character_,
      run_status = manifest$run_status %||% NA_character_,
      step_index = step_value(step, "step_index", NA_integer_),
      step_id = step_value(step, "step_id", NA_character_),
      label = step_value(step, "label", NA_character_),
      script = step_value(step, "script", NA_character_),
      status = step_value(step, "status", NA_character_),
      started_at = step_value(step, "started_at", NA_character_),
      completed_at = step_value(step, "completed_at", NA_character_),
      elapsed_minutes = elapsed_minutes,
      log_file = step_value(step, "log_file", NA_character_),
      reason = step_value(step, "reason", NA_character_),
      error = step_value(step, "error", NA_character_),
      review_label = step_value(step, "review_label", NA_character_),
      stringsAsFactors = FALSE
    )
  })

  data <- do.call(rbind, rows)
  data[, columns, drop = FALSE]
}

write_pipeline_timing_workbook <- function(manifest, timing_file) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required to write pipeline timing workbooks.", call. = FALSE)
  }

  dir.create(dirname(timing_file), recursive = TRUE, showWarnings = FALSE)
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "step_times")
  openxlsx::writeData(wb, "step_times", pipeline_timing_data(manifest), keepNA = TRUE)
  openxlsx::freezePane(wb, "step_times", firstRow = TRUE)
  openxlsx::saveWorkbook(wb, timing_file, overwrite = TRUE)
  invisible(timing_file)
}

write_pipeline_outputs <- function(manifest, manifest_file, timing_file = NULL) {
  write_pipeline_manifest(manifest, manifest_file)
  if (!is.null(timing_file)) {
    tryCatch(
      write_pipeline_timing_workbook(manifest, timing_file),
      error = function(e) warning(conditionMessage(e), call. = FALSE)
    )
  }
  invisible(TRUE)
}

set_pipeline_env <- function(project_dir, country, mode) {
  names <- c("UN_SUBNATIONAL_HOME", "UN_SUBNATIONAL_COUNTRY", "UN_SUBNATIONAL_MODE")
  old <- setNames(Sys.getenv(names, unset = NA_character_), names)
  Sys.setenv(
    UN_SUBNATIONAL_HOME = project_dir,
    UN_SUBNATIONAL_COUNTRY = country,
    UN_SUBNATIONAL_MODE = mode
  )
  old
}

append_step_result <- function(manifest, result) {
  manifest$steps[[length(manifest$steps) + 1L]] <- result
  manifest
}

run_country_pipeline <- function(country,
                                 mode = "preview",
                                 render_summary = TRUE,
                                 report_year = 2026L,
                                 project_dir = pipeline_project_dir(),
                                 prompt = readline) {
  mode <- normalize_pipeline_mode(mode)
  report_year <- normalize_report_year(report_year)
  project_dir <- pipeline_project_dir(project_dir)
  old_env <- set_pipeline_env(project_dir, country, mode)
  old_wd <- getwd()
  on.exit({
    restore_env(old_env)
    setwd(old_wd)
  }, add = TRUE)
  setwd(project_dir)

  context <- new.env(parent = globalenv())
  context$project_dir <- project_dir
  context$country <- country
  context$report_year <- report_year

  log_dir <- file.path(project_dir, "Results", country, "logs", pipeline_timestamp())
  dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  manifest_file <- file.path(log_dir, "pipeline_manifest.json")
  timing_file <- file.path(log_dir, "pipeline_step_times.xlsx")
  manifest <- list(
    country = country,
    mode = mode,
    render_summary = isTRUE(render_summary),
    report_year = report_year,
    run_status = "running",
    started_at = pipeline_time_iso(),
    completed_at = NULL,
    log_dir = log_dir,
    manifest_file = manifest_file,
    timing_file = timing_file,
    steps = list()
  )
  write_pipeline_outputs(manifest, manifest_file, timing_file)

  step_index <- 0L
  setup_steps <- make_pipeline_setup_steps(country, project_dir)
  for (step in setup_steps) {
    step_index <- step_index + 1L
    result <- run_pipeline_step(step, step_index, context, mode, log_dir, prompt = prompt)
    manifest <- append_step_result(manifest, result)
    if (identical(result$status, "failed")) {
      manifest$run_status <- "failed"
      manifest$completed_at <- pipeline_time_iso()
      write_pipeline_outputs(manifest, manifest_file, timing_file)
      stop("Pipeline failed at step '", step$id, "': ", result$error, call. = FALSE)
    }
    write_pipeline_outputs(manifest, manifest_file, timing_file)
  }

  steps <- make_pipeline_steps(country, context, project_dir, render_summary = render_summary)
  for (step in steps) {
    step_index <- step_index + 1L
    result <- run_pipeline_step(step, step_index, context, mode, log_dir, prompt = prompt)
    manifest <- append_step_result(manifest, result)

    if (identical(result$status, "failed")) {
      manifest$run_status <- "failed"
      manifest$completed_at <- pipeline_time_iso()
      write_pipeline_outputs(manifest, manifest_file, timing_file)
      stop("Pipeline failed at step '", step$id, "': ", result$error, call. = FALSE)
    }

    if (identical(result$status, "review_pending")) {
      manifest$run_status <- "review_pending"
      manifest$completed_at <- pipeline_time_iso()
      write_pipeline_outputs(manifest, manifest_file, timing_file)
      stop("Pipeline stopped for preview review at step '", step$id, "'.", call. = FALSE)
    }

    write_pipeline_outputs(manifest, manifest_file, timing_file)
  }

  manifest$run_status <- "completed"
  manifest$completed_at <- pipeline_time_iso()
  write_pipeline_outputs(manifest, manifest_file, timing_file)
  message("Pipeline completed for ", country, ".")
  message("Manifest: ", manifest_file)
  message("Step timing workbook: ", timing_file)
  invisible(manifest)
}
