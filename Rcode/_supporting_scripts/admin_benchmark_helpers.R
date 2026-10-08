weight_admin_draw_matrix <- function(draw_matrix, admin_weights) {
  if (is.null(colnames(draw_matrix))) {
    stop("draw_matrix must have region names as column names.", call. = FALSE)
  }
  required_weight_cols <- c("region", "proportion")
  missing_weight_cols <- setdiff(required_weight_cols, names(admin_weights))
  if (length(missing_weight_cols) > 0) {
    stop("admin_weights is missing columns: ",
         paste(missing_weight_cols, collapse = ", "),
         call. = FALSE)
  }
  if (anyDuplicated(admin_weights$region)) {
    stop("admin_weights contains duplicate regions.", call. = FALSE)
  }

  weight_order <- match(colnames(draw_matrix), admin_weights$region)
  if (anyNA(weight_order)) {
    stop("Missing Admin weights for regions: ",
         paste(colnames(draw_matrix)[is.na(weight_order)], collapse = ", "),
         call. = FALSE)
  }

  as.numeric(draw_matrix %*% admin_weights$proportion[weight_order])
}

aggregate_admin_draws_to_national <- function(admin_draws, admin_weights, years) {
  if (length(admin_draws) == 0) {
    stop("admin_draws is empty.", call. = FALSE)
  }
  required_weight_cols <- c("region", "proportion", "years")
  missing_weight_cols <- setdiff(required_weight_cols, names(admin_weights))
  if (length(missing_weight_cols) > 0) {
    stop("admin_weights is missing columns: ",
         paste(missing_weight_cols, collapse = ", "),
         call. = FALSE)
  }

  draw_years <- as.integer(vapply(admin_draws, function(x) x$years, numeric(1)))
  draw_regions <- vapply(admin_draws, function(x) x$region, character(1))

  out <- lapply(years, function(year) {
    idx <- which(draw_years == year)
    if (length(idx) == 0) {
      stop("No Admin draws found for year ", year, ".", call. = FALSE)
    }

    year_weights <- admin_weights[admin_weights$years == year,
                                  c("region", "proportion")]
    weight_order <- match(draw_regions[idx], year_weights$region)
    if (anyNA(weight_order)) {
      missing_regions <- draw_regions[idx][is.na(weight_order)]
      stop("Missing Admin weights for year ", year, ": ",
           paste(unique(missing_regions), collapse = ", "),
           call. = FALSE)
    }

    draw_matrix <- do.call(
      rbind,
      lapply(admin_draws[idx], function(x) as.numeric(x$draws))
    )
    colSums(draw_matrix * year_weights$proportion[weight_order])
  })
  names(out) <- as.character(years)
  out
}

compute_admin_benchmark_adjustment <- function(country,
                                               years,
                                               admin_draws,
                                               admin_weights,
                                               igme_ests) {
  bench.adj <- expand.grid(country = country, years = years)
  bench.adj$est <- bench.adj$igme <- NA_real_
  for (i in seq_len(nrow(bench.adj))) {
    year <- bench.adj$years[i]
    idx <- which(vapply(admin_draws, function(d) as.numeric(d$years), 0) == year)
    regions <- vapply(admin_draws[idx], function(d) d$region, "")
    w <- admin_weights[admin_weights$years == year, ]
    if (anyDuplicated(regions) || anyDuplicated(w$region) ||
        !setequal(regions, w$region) || any(!is.finite(w$proportion)) ||
        any(w$proportion < 0) || abs(sum(w$proportion) - 1) > 1e-6) {
      stop("Invalid benchmark region coverage or population weights for ", year)
    }
    bench.adj$est[i] <- sum(vapply(admin_draws[idx], function(d) {
      if (!length(d$draws) || any(!is.finite(d$draws))) stop("Invalid posterior draws")
      stats::median(d$draws)
    }, 0) * w$proportion[match(regions, w$region)])
    if (sum(igme_ests$year == year) != 1L) stop("Missing/duplicate national target for ", year)
    bench.adj$igme[i] <- igme_ests$OBS_VALUE[igme_ests$year == year]
  }
  bench.adj$ratio <- bench.adj$est / bench.adj$igme
  bench.adj$factor <- 1 / bench.adj$ratio
  if (any(!is.finite(bench.adj$factor)) || any(bench.adj$factor <= 0) ||
      any(!is.finite(bench.adj$igme)) || any(bench.adj$igme <= 0 | bench.adj$igme >= 1)) {
    stop("Invalid national benchmark target or scaling factor")
  }
  bench.adj$method <- "direct_pointmedian_v1"
  bench.adj
}

# HIV offsets belong only to the base fit. National medians are fixed targets.
# A common outcome/year factor preserves regional and urban/rural draw ratios.
benchmark_admin_result <- function(result, adjustment) {
  if (!is.null(result$benchmark)) stop("Input is already benchmarked")
  if (anyDuplicated(adjustment$years) || any(!is.finite(adjustment$factor)) ||
      any(adjustment$factor <= 0)) stop("Invalid annual benchmark factors")
  factor_for <- function(years) {
    ix <- match(as.numeric(as.character(years)), adjustment$years)
    if (anyNA(ix)) stop("Missing benchmark year")
    adjustment$factor[ix]
  }
  scale_draws <- function(ds) lapply(ds, function(d) {
    d$draws <- d$draws * factor_for(d$years)
    if (!length(d$draws) || any(!is.finite(d$draws)) ||
        any(d$draws < 0 | d$draws > 1)) stop("Benchmarked draws outside [0,1]; no clipping applied")
    d
  })
  result$draws.est.overall <- scale_draws(result$draws.est.overall)
  if (!is.null(result$draws.est)) result$draws.est <- scale_draws(result$draws.est)
  summarize <- function(tab, ds) {
    if (is.null(tab)) return(NULL)
    key <- function(x) paste(x$region, as.character(x$years),
                             if (is.null(x[["strata", exact=TRUE]])) "" else as.character(x[["strata", exact=TRUE]]))
    ids <- vapply(ds, key, "")
    ix <- match(key(tab), ids)
    if (anyDuplicated(ids) || anyNA(ix)) stop("Draw/summary keys do not match")
    ci <- if (is.null(result$CI)) .9 else result$CI
    if (length(ci) != 1 || !is.finite(ci) || ci <= 0 || ci >= 1) stop("Invalid CI")
    tab$median <- vapply(ds[ix], function(d) stats::median(d$draws), 0)
    tab$mean <- vapply(ds[ix], function(d) mean(d$draws), 0)
    tab$variance <- vapply(ds[ix], function(d) stats::var(d$draws), 0)
    tab$lower <- vapply(ds[ix], function(d) stats::quantile(d$draws, (1-ci)/2, names=FALSE), 0)
    tab$upper <- vapply(ds[ix], function(d) stats::quantile(d$draws, (1+ci)/2, names=FALSE), 0)
    tab
  }
  result$overall <- summarize(result$overall, result$draws.est.overall)
  if (!is.null(result$stratified)) {
    result$stratified <- summarize(result$stratified, result$draws.est)
  }
  # Latent INLA samples remain samples of the HIV-only fit, not calibrated rates.
  result$source.fit.draws <- result$draws
  result$draws <- NULL
  result$benchmark <- list(method="direct_pointmedian_v1", adjustment=adjustment,
                          national_uncertainty_propagated=FALSE,
                          diagnostics="HIV-only source fit; subsequent output calibration")
  result
}

is_direct_benchmark_file <- function(path) {
  if (!file.exists(path)) return(FALSE)
  tryCatch({
    e <- new.env(); n <- load(path, e)
    length(n) == 1L && identical(e[[n]]$benchmark$method, "direct_pointmedian_v1")
  }, error=function(e) FALSE)
}

benchmark_diagnostic_draws <- function(result) {
  direct <- identical(result$benchmark$method, "direct_pointmedian_v1")
  samples <- if (direct) result$source.fit.draws else result[["draws", exact=TRUE]]
  if (!length(samples) || is.null(samples[[1]]$latent)) {
    stop("Diagnostic latent samples are missing from the source fit")
  }
  samples
}

# Preserve diagnostic filenames/object names for consumers, but label their origin.
save_benchmark_source_diagnostics <- function(country, metric_dir, base_stub, bench_stub,
                                              envir=parent.frame()) {
  root <- file.path("Betabinomial", metric_dir)
  if (exists("runtime_path", mode="function", inherits=TRUE)) {
    root <- runtime_path(root)
  }
  base_var <- gsub("_", ".", base_stub, fixed=TRUE)
  bench_var <- gsub("_", ".", bench_stub, fixed=TRUE)
  for (component in c("temporals", "hyperpar", "fixed")) {
    src <- file.path(root, paste0(country, "_", component, "_", base_stub, ".rda"))
    e <- new.env(); names <- load(src, e)
    expected <- paste0("bb.", component, ".", base_var)
    if (!expected %in% names) stop("Missing source diagnostic: ", expected)
    name <- paste0("bb.", component, ".", bench_var)
    assign(name, e[[expected]], envir=envir)
    save(list=name, envir=envir,
         file=file.path(root, paste0(country, "_", component, "_", bench_stub, ".rda")))
  }
  src <- file.path(root, paste0(country, "_fit_", base_stub, ".txt"))
  writeLines(c("National benchmarking: direct_pointmedian_v1; fixed national medians.",
               "Diagnostics below describe the HIV-adjusted source fit, not an additional benchmark refit.",
               readLines(src, warn=FALSE)),
             file.path(root, paste0(country, "_fit_", bench_stub, ".txt")))
  invisible(NULL)
}
