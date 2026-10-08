escape_regex <- function(x) {
  gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x)
}

discover_direct_time_models <- function(res.dir, country) {
  direct_dirs <- file.path(res.dir, "Direct", c("NMR", "U5MR"))
  direct_dirs <- direct_dirs[base::dir.exists(direct_dirs)]
  if (length(direct_dirs) == 0) {
    return(character())
  }

  files <- unlist(lapply(direct_dirs, function(path) {
    base::list.files(path, pattern = "\\.rda$", full.names = FALSE)
  }), use.names = FALSE)

  if (length(files) == 0) {
    return(character())
  }

  pattern <- paste0(
    "^", escape_regex(country),
    "_res_(natl|admin[0-9]+)_([^_]+)_(yearly_)?(nmr|u5)_SmoothedDirect(_yearly)?\\.rda$"
  )
  matches <- regexec(pattern, files)
  parts <- regmatches(files, matches)
  models <- vapply(parts[lengths(parts) > 0], function(match) match[[3]], character(1))

  sort(unique(models))
}

comparison_methods_available <- function(natl.all,
                                         group = c("smooth_direct", "bb8", "bb8_bench")) {
  group <- match.arg(group)
  available <- unique(natl.all$method)

  smooth_direct <- c(
    "natl.sd.yearly",
    "aggre.sd.adm1",
    "aggre.sd.yearly.adm1",
    "aggre.sd.adm2",
    "aggre.sd.yearly.adm2"
  )
  bb8 <- available[grepl("^natl\\.bb|^aggre\\.adm[0-9]+\\..*BB8", available)]

  methods <- switch(
    group,
    smooth_direct = c(smooth_direct, "igme"),
    bb8 = c("natl.sd.yearly", bb8, "igme"),
    bb8_bench = c(
      "natl.sd.yearly",
      "igme",
      bb8[!grepl("\\.bench$", bb8)],
      bb8[grepl("\\.bench$", bb8)]
    )
  )

  unique(methods[methods %in% available])
}

comparison_palette <- function(n) {
  if (n <= 12) {
    return(RColorBrewer::brewer.pal(n = max(3, n), name = "Paired")[seq_len(n)])
  }

  grDevices::hcl.colors(n, palette = "Dark 3")
}

comparison_y_limits <- function(natl.all,
                                methods.use,
                                outcome = c("nmr", "u5"),
                                pad_fraction = 0.08) {
  outcome <- match.arg(outcome)
  value_col <- paste0("median_", outcome)

  values <- natl.all[natl.all$method %in% methods.use, value_col] * 1000
  values <- values[is.finite(values)]

  if (length(values) == 0) {
    return(c(0, 1))
  }

  y_min <- min(values)
  y_max <- max(values)
  y_span <- y_max - y_min
  y_pad <- if (y_span > 0) {
    y_span * pad_fraction
  } else {
    max(abs(y_max) * pad_fraction, 1)
  }

  c(max(0, y_min - y_pad), y_max + y_pad)
}

open_plot_pdf <- function(file, ...) {
  tryCatch({
    pdf(file, ...)
    invisible(file)
  }, error = function(err) {
    fallback <- file.path(
      dirname(file),
      paste0(
        tools::file_path_sans_ext(basename(file)),
        "_",
        format(Sys.time(), "%Y%m%d_%H%M%S"),
        ".pdf"
      )
    )
    warning(
      "Could not open existing plot file for writing: ", file,
      "\nWriting fallback file instead: ", fallback
    )
    pdf(fallback, ...)
    invisible(fallback)
  })
}
