exclude_degenerate_direct_variances <- function(
    data,
    variance_floor = 1e-12,
    label = "direct estimates") {
  required_columns <- c("logit.est", "var.est", "logit.prec")
  missing_columns <- setdiff(required_columns, names(data))
  if (length(missing_columns) > 0L) {
    stop(
      "Cannot sanitize ", label, "; missing columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  degenerate <- is.finite(data$var.est) & data$var.est <= variance_floor
  estimate_columns <- intersect(
    c("mean", "lower", "upper", "logit.est", "var.est", "logit.prec"),
    names(data)
  )
  data[degenerate, estimate_columns] <- NA_real_
  excluded <- sum(degenerate)
  attr(data, "excluded_degenerate_variances") <- as.integer(excluded)

  if (excluded > 0L) {
    message(
      "Excluded ", excluded, " zero or numerically degenerate sampling ",
      "variance estimate(s) from ", label, " smoothing input."
    )
  }

  data
}

adjacency_has_edges <- function(Amat) {
  if (is.null(Amat) || length(Amat) == 0L) {
    return(FALSE)
  }
  if (!is.matrix(Amat) || nrow(Amat) != ncol(Amat)) {
    stop("The adjacency matrix must be square.", call. = FALSE)
  }
  off_diagonal <- row(Amat) != col(Amat)
  any(is.finite(Amat[off_diagonal]) & Amat[off_diagonal] != 0)
}

smooth_direct_independently <- function(data, region_names, fit_region) {
  if (!is.function(fit_region)) {
    stop("fit_region must be a function.", call. = FALSE)
  }

  fits <- list()
  results <- list()
  for (region_name in region_names) {
    region_data <- data[data$region == region_name, , drop = FALSE]
    if (nrow(region_data) == 0L) {
      next
    }
    region_data$region <- "All"
    region_fit <- fit_region(region_data, region_name)
    if (!is.list(region_fit) ||
        is.null(region_fit$fit) ||
        is.null(region_fit$result)) {
      stop(
        "fit_region must return a list containing fit and result.",
        call. = FALSE
      )
    }
    region_result <- region_fit$result
    region_result$region <- region_name
    fits[[region_name]] <- region_fit$fit
    results[[region_name]] <- region_result
  }

  if (length(results) == 0L) {
    stop("No regions contained direct estimates to smooth.", call. = FALSE)
  }

  list(fit = fits, result = do.call(rbind, results))
}
