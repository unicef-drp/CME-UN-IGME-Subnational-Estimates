final_admin2_recovery_plan <- function(final_model) {
  if (!is.list(final_model) ||
      !identical(final_model$bench.model, "bench")) {
    stop(
      "BB8 final Admin-2 recovery requires a benchmarked final model.",
      call. = FALSE
    )
  }

  branch <- as.character(final_model$strata.model)[1]
  if (!branch %in% c("strat", "unstrat")) {
    stop(
      "Unsupported final Admin-2 recovery branch: ", branch,
      call. = FALSE
    )
  }

  all_surveys <- identical(branch, "unstrat")
  suffix <- if (all_surveys) "unstrat_%s_allsurveys" else "strat_%s"
  list(
    branch = branch,
    data_scope = if (all_surveys) "all_surveys" else "same_frame",
    stratified = identical(branch, "strat"),
    stubs = list(
      nmr = list(
        base = sprintf(paste0("adm2_", suffix), "nmr"),
        bench = paste0(
          sprintf(paste0("adm2_", suffix), "nmr"),
          "_bench"
        )
      ),
      u5 = list(
        base = sprintf(paste0("adm2_", suffix), "u5"),
        bench = paste0(
          sprintf(paste0("adm2_", suffix), "u5"),
          "_bench"
        )
      )
    )
  )
}

final_admin2_expected_outputs <- function(country, res_dir, plan) {
  component_paths <- function(metric_dir, stub) {
    metric_path <- file.path(res_dir, "Betabinomial", metric_dir)
    file.path(
      metric_path,
      c(
        paste0(country, "_fit_", stub, ".txt"),
        paste0(country, "_temporals_", stub, ".rda"),
        paste0(country, "_hyperpar_", stub, ".rda"),
        paste0(country, "_fixed_", stub, ".rda"),
        paste0(country, "_res_", stub, ".rda")
      )
    )
  }

  c(
    component_paths("NMR", plan$stubs$nmr$bench),
    component_paths("U5MR", plan$stubs$u5$bench)
  )
}

final_admin2_benchmark_path <- function(res_dir, metric_dir, base_stub) {
  adjustment_stub <- sub("_allsurveys$", "", base_stub)
  file.path(
    res_dir,
    "Betabinomial",
    metric_dir,
    paste0(adjustment_stub, "_benchmarks.rda")
  )
}

save_final_admin2_benchmark_adjustment <- function(adjustment, path) {
  bench.adj <- adjustment
  save(bench.adj, file = path)
  invisible(path)
}

validate_final_admin2_inputs <- function(
    admin2_names,
    admin2_matrix,
    weight_u1,
    weight_u5,
    years) {
  ids <- as.character(admin2_names$Internal)
  if (length(ids) == 0L || anyNA(ids) || any(!nzchar(ids)) ||
      anyDuplicated(ids)) {
    stop("Admin-2 name map is incomplete.", call. = FALSE)
  }
  if (!identical(dim(admin2_matrix), c(length(ids), length(ids))) ||
      !identical(rownames(admin2_matrix), ids) ||
      !identical(colnames(admin2_matrix), ids)) {
    stop("Admin-2 adjacency does not match the name map.", call. = FALSE)
  }

  validate_weights <- function(weights, label) {
    required <- c("region", "years", "proportion")
    if (!is.data.frame(weights) || !all(required %in% names(weights))) {
      stop(label, " weights have an invalid schema.", call. = FALSE)
    }
    keys <- paste(as.character(weights$region), weights$years, sep = "|")
    expected_keys <- as.vector(outer(ids, years, paste, sep = "|"))
    if (!setequal(keys, expected_keys) || anyDuplicated(keys) ||
        any(!is.finite(weights$proportion)) ||
        any(weights$proportion < 0)) {
      stop(label, " weights fail coverage or value checks.", call. = FALSE)
    }
    totals <- stats::aggregate(proportion ~ years, weights, sum)
    if (any(abs(totals$proportion - 1) > 1e-6)) {
      stop(label, " weights do not sum to one by year.", call. = FALSE)
    }
  }

  validate_weights(weight_u1, "Admin-2 U1")
  validate_weights(weight_u5, "Admin-2 U5")
  TRUE
}

validate_final_admin2_strata_weights <- function(weights, ids, years, label) {
  required <- c("region", "years", "urban", "rural")
  if (!is.data.frame(weights) || !all(required %in% names(weights))) {
    stop(label, " stratum weights have an invalid schema.", call. = FALSE)
  }
  keys <- paste(as.character(weights$region), weights$years, sep = "|")
  expected_keys <- as.vector(outer(ids, years, paste, sep = "|"))
  if (!setequal(keys, expected_keys) || anyDuplicated(keys) ||
      any(!is.finite(weights$urban)) || any(!is.finite(weights$rural)) ||
      any(weights$urban < 0 | weights$urban > 1) ||
      any(weights$rural < 0 | weights$rural > 1) ||
      any(abs(weights$urban + weights$rural - 1) > 1e-6)) {
    stop(label, " stratum weights fail coverage or value checks.",
         call. = FALSE)
  }
  TRUE
}

prepare_final_admin2_all_survey_data <- function(
    country,
    data_dir,
    home_dir,
    do_hiv_adjustment,
    beg_year,
    end_year,
    hiv_loader) {
  data_env <- new.env(parent = emptyenv())
  data_path <- file.path(data_dir, paste0(country, "_cluster_dat.rda"))
  if (!file.exists(data_path)) {
    stop("Missing all-survey model data: ", data_path, call. = FALSE)
  }
  loaded <- load(data_path, envir = data_env)
  if (!"mod.dat" %in% loaded) {
    stop("All-survey data does not contain mod.dat: ", data_path,
         call. = FALSE)
  }
  mod_dat <- data_env$mod.dat
  mod_dat$years <- as.numeric(as.character(mod_dat$years))
  mod_dat$country <- as.character(country)
  survey_years <- unique(mod_dat$survey)

  if (isTRUE(do_hiv_adjustment)) {
    hiv_adj <- hiv_loader(
      file.path(home_dir, "Data", "HIV", "HIVAdjustments.rda"),
      country
    )
    national_adjustment <- unique(hiv_adj$area)[1] == country
    if (national_adjustment) {
      adj_frame <- hiv_adj
      adj_varnames <- c("country", "survey", "years")
    } else {
      adj_frame <- hiv_adj
      mod_dat$area <- mod_dat$admin1.name
      if (identical(country, "Mozambique")) {
        mod_dat$area[mod_dat$area == "Maputo City"] <- "Maputo"
      }
      adj_varnames <- c("country", "area", "survey", "years")
    }
    adj_frame <- adj_frame[
      adj_frame$survey %in% survey_years,
      c(adj_varnames, "ratio"),
      drop = FALSE
    ]
  } else {
    adj_frame <- expand.grid(
      years = beg_year:end_year,
      country = country,
      stringsAsFactors = FALSE
    )
    adj_frame$ratio <- 1
    adj_varnames <- c("country", "years")
  }

  list(
    mod_dat = mod_dat,
    adj_frame = adj_frame,
    adj_varnames = adj_varnames,
    survey_years = survey_years
  )
}

save_final_admin2_components <- function(
    bb,
    country,
    metric_dir,
    file_stub,
    res_dir,
    beg_year,
    end_year,
    temporal_diagnostic) {
  metric_path <- file.path(res_dir, "Betabinomial", metric_dir)
  dir.create(metric_path, recursive = TRUE, showWarnings = FALSE)
  variable_stub <- gsub("_", ".", file_stub, fixed = TRUE)
  fit <- bb[[1]]
  result <- bb[[2]]
  temporals <- temporal_diagnostic(
    bb$fit,
    admin_level = "Admin2",
    year_label = beg_year:end_year
  )
  hyperpar <- fit$fit$summary.hyperpar
  fixed <- fit$fit$summary.fixed

  object_env <- new.env(parent = emptyenv())
  object_names <- c(
    temporals = paste0("bb.temporals.", variable_stub),
    hyperpar = paste0("bb.hyperpar.", variable_stub),
    fixed = paste0("bb.fixed.", variable_stub),
    result = paste0("bb.res.", variable_stub)
  )
  assign(object_names[["temporals"]], temporals, envir = object_env)
  assign(object_names[["hyperpar"]], hyperpar, envir = object_env)
  assign(object_names[["fixed"]], fixed, envir = object_env)
  assign(object_names[["result"]], result, envir = object_env)

  paths <- c(
    fit = file.path(metric_path, paste0(country, "_fit_", file_stub, ".txt")),
    temporals = file.path(
      metric_path, paste0(country, "_temporals_", file_stub, ".rda")
    ),
    hyperpar = file.path(
      metric_path, paste0(country, "_hyperpar_", file_stub, ".rda")
    ),
    fixed = file.path(
      metric_path, paste0(country, "_fixed_", file_stub, ".rda")
    ),
    result = file.path(
      metric_path, paste0(country, "_res_", file_stub, ".rda")
    )
  )
  utils::capture.output(summary(fit), file = paths[["fit"]])
  if (!is.null(result$benchmark)) {
    writeLines(c("Direct national calibration; diagnostics describe the HIV-only source fit.",
                 readLines(paths[["fit"]], warn=FALSE)), paths[["fit"]])
  }
  save(
    list = object_names[["temporals"]],
    file = paths[["temporals"]],
    envir = object_env
  )
  save(
    list = object_names[["hyperpar"]],
    file = paths[["hyperpar"]],
    envir = object_env
  )
  save(
    list = object_names[["fixed"]],
    file = paths[["fixed"]],
    envir = object_env
  )
  save(
    list = object_names[["result"]],
    file = paths[["result"]],
    envir = object_env
  )

  list(paths = paths, result = result)
}

run_final_admin2_only <- function(
    country,
    res_dir,
    plan,
    mod_dat,
    admin2_matrix,
    admin2_names,
    weight_u1,
    weight_u5,
    igme_nmr,
    igme_u5,
    adj_frame,
    adj_varnames,
    beg_year,
    end_year,
    get_bb8,
    temporal_diagnostic,
    benchmark_adjustment,
    weight_strata_u1 = NULL,
    weight_strata_u5 = NULL) {
  validate_final_admin2_inputs(
    admin2_names = admin2_names,
    admin2_matrix = admin2_matrix,
    weight_u1 = weight_u1,
    weight_u5 = weight_u5,
    years = beg_year:end_year
  )
  ids <- as.character(admin2_names$Internal)
  if (isTRUE(plan$stratified)) {
    validate_final_admin2_strata_weights(
      weight_strata_u1, ids, beg_year:end_year, "Admin-2 U1"
    )
    validate_final_admin2_strata_weights(
      weight_strata_u5, ids, beg_year:end_year, "Admin-2 U5"
    )
  }

  written <- character(0)
  run_outcome <- function(key, metric_dir, outcome, population_weights,
                          stratum_weights, igme_estimates) {
    base_stub <- plan$stubs[[key]]$base
    bench_stub <- plan$stubs[[key]]$bench
    message("Fitting final Admin-2 base model: ", base_stub)
    base <- get_bb8(
      mod_dat,
      country,
      beg.year = beg_year,
      end.year = end_year,
      Amat = admin2_matrix,
      admin.level = "Admin2",
      stratified = plan$stratified,
      weight.strata = if (plan$stratified) stratum_weights else NULL,
      outcome = outcome,
      time.model = "ar1",
      st.time.model = "ar1",
      adj.frame = adj_frame,
      adj.varnames = adj_varnames,
      nsim = 1000
    )
    base_saved <- save_final_admin2_components(
      bb = base,
      country = country,
      metric_dir = metric_dir,
      file_stub = base_stub,
      res_dir = res_dir,
      beg_year = beg_year,
      end_year = end_year,
      temporal_diagnostic = temporal_diagnostic
    )
    written <<- c(written, unname(base_saved$paths))

    bench_adj <- benchmark_adjustment(
      country = country,
      years = beg_year:end_year,
      admin_draws = base_saved$result$draws.est.overall,
      admin_weights = population_weights,
      igme_ests = igme_estimates
    )
    benchmark_path <- final_admin2_benchmark_path(
      res_dir = res_dir,
      metric_dir = metric_dir,
      base_stub = plan$stubs[[key]]$base
    )
    save_final_admin2_benchmark_adjustment(bench_adj, benchmark_path)
    written <<- c(written, benchmark_path)

    message("Direct national calibration of final Admin-2 estimates: ", bench_stub)
    benchmarked <- base
    benchmarked$results <- benchmark_admin_result(base_saved$result, bench_adj)
    benchmarked_saved <- save_final_admin2_components(
      bb = benchmarked,
      country = country,
      metric_dir = metric_dir,
      file_stub = bench_stub,
      res_dir = res_dir,
      beg_year = beg_year,
      end_year = end_year,
      temporal_diagnostic = temporal_diagnostic
    )
    written <<- c(written, unname(benchmarked_saved$paths))
    invisible(NULL)
  }

  run_outcome(
    key = "nmr",
    metric_dir = "NMR",
    outcome = "nmr",
    population_weights = weight_u1,
    stratum_weights = weight_strata_u1,
    igme_estimates = igme_nmr
  )
  gc()
  run_outcome(
    key = "u5",
    metric_dir = "U5MR",
    outcome = "u5mr",
    population_weights = weight_u5,
    stratum_weights = weight_strata_u5,
    igme_estimates = igme_u5
  )
  gc()

  expected <- final_admin2_expected_outputs(country, res_dir, plan)
  missing <- expected[
    !file.exists(expected) | is.na(file.info(expected)$size) |
      file.info(expected)$size <= 0
  ]
  if (length(missing) > 0L) {
    stop(
      "Final Admin-2 recovery did not produce: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  unique(normalizePath(written, winslash = "/", mustWork = TRUE))
}
