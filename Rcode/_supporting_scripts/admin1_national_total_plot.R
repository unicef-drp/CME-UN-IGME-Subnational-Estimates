#' Shared Admin-1 overview charts with the official national total.

normalize_admin1_national_outcome <- function(outcome) {
  outcome <- tolower(as.character(outcome))
  if (length(outcome) != 1L || is.na(outcome) ||
      !outcome %in% c("nmr", "u5")) {
    stop("outcome must be 'nmr' or 'u5'.", call. = FALSE)
  }
  outcome
}

require_admin1_national_columns <- function(data, columns, label) {
  missing_columns <- setdiff(columns, names(data))
  if (length(missing_columns) > 0L) {
    stop(
      label, " is missing required column(s): ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }
}

admin1_national_total_filename <- function(
    country,
    outcome,
    time_model,
    strata_model,
    bench_model = "") {
  outcome <- normalize_admin1_national_outcome(outcome)
  values <- c(country, time_model, strata_model, bench_model)
  if (any(is.na(values)) || any(!nzchar(values[seq_len(3L)]))) {
    stop(
      "country, time_model, and strata_model must be non-empty strings.",
      call. = FALSE
    )
  }
  bench_suffix <- if (nzchar(bench_model)) paste0("_", bench_model) else ""
  paste0(
    country, "_Admin1_", outcome, "_NationalTotal_", time_model, "_",
    strata_model, bench_suffix, ".pdf"
  )
}

prepare_admin1_national_total_data <- function(
    admin_data,
    igme_frame,
    outcome) {
  outcome <- normalize_admin1_national_outcome(outcome)
  year_column <- if ("years.num" %in% names(admin_data)) {
    "years.num"
  } else {
    "years"
  }
  require_admin1_national_columns(
    admin_data,
    c("region", year_column, "median"),
    "Admin-1 result"
  )
  national_column <- paste0("median_", outcome)
  require_admin1_national_columns(
    igme_frame,
    c("years", national_column),
    "Official national result"
  )

  admin <- data.frame(
    region = as.character(admin_data$region),
    year = as.numeric(as.character(admin_data[[year_column]])),
    value = as.numeric(admin_data$median) * 1000,
    series = as.character(admin_data$region),
    stringsAsFactors = FALSE
  )
  admin <- admin[
    !is.na(admin$region) & nzchar(admin$region) &
      is.finite(admin$year) & is.finite(admin$value),
    , drop = FALSE
  ]
  if (nrow(admin) == 0L) {
    stop("Admin-1 result has no finite region-year medians.", call. = FALSE)
  }

  national <- data.frame(
    year = as.numeric(as.character(igme_frame$years)),
    value = as.numeric(igme_frame[[national_column]]) * 1000,
    series = "National total",
    stringsAsFactors = FALSE
  )
  year_range <- range(admin$year)
  national <- national[
    is.finite(national$year) & is.finite(national$value) &
      national$year >= year_range[[1]] & national$year <= year_range[[2]],
    , drop = FALSE
  ]
  if (nrow(national) == 0L) {
    stop(
      "Official national result has no finite values in the Admin-1 year range.",
      call. = FALSE
    )
  }

  list(admin = admin, national = national)
}

build_admin1_national_total_plot <- function(
    admin_data,
    igme_frame,
    outcome,
    country_label) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for national-total charts.",
         call. = FALSE)
  }
  outcome <- normalize_admin1_national_outcome(outcome)
  prepared <- prepare_admin1_national_total_data(
    admin_data = admin_data,
    igme_frame = igme_frame,
    outcome = outcome
  )
  upper_limit <- max(
    prepared$admin$value,
    prepared$national$value,
    na.rm = TRUE
  )
  upper_limit <- if (is.finite(upper_limit) && upper_limit > 0) {
    upper_limit * 1.05
  } else {
    1
  }
  outcome_label <- if (outcome == "u5") "U5MR" else "NMR"
  region_levels <- sort(unique(prepared$admin$series))
  series_levels <- c(region_levels, "National total")
  region_colours <- grDevices::hcl.colors(
    length(region_levels),
    palette = "Dark 3"
  )
  series_colours <- c(
    stats::setNames(region_colours, region_levels),
    "National total" = "#000000"
  )
  legend_columns <- min(
    4L,
    max(2L, as.integer(ceiling(length(series_levels) / 5)))
  )

  ggplot2::ggplot() +
    ggplot2::geom_line(
      data = prepared$admin,
      ggplot2::aes(x = year, y = value, group = series, colour = series),
      linewidth = 0.65,
      alpha = 0.85
    ) +
    ggplot2::geom_line(
      data = prepared$national,
      ggplot2::aes(x = year, y = value, colour = series),
      linewidth = 1.25
    ) +
    ggplot2::scale_colour_manual(
      values = series_colours,
      breaks = series_levels,
      limits = series_levels,
      labels = scales::label_wrap(width = 24),
      drop = FALSE,
      name = NULL
    ) +
    ggplot2::scale_y_continuous(
      limits = c(0, upper_limit),
      expand = ggplot2::expansion(mult = c(0, 0.01))
    ) +
    ggplot2::labs(
      title = as.character(country_label),
      subtitle = paste0("Admin-1 ", outcome_label, " and National total"),
      x = "Year",
      y = paste0(outcome_label, ": deaths per 1000 live births"),
      colour = NULL
    ) +
    ggplot2::theme_light() +
    ggplot2::theme(
      legend.position = "bottom",
      legend.title = ggplot2::element_blank(),
      legend.text = ggplot2::element_text(size = 7)
    ) +
    ggplot2::guides(
      colour = ggplot2::guide_legend(
        ncol = legend_columns,
        byrow = TRUE,
        override.aes = list(linewidth = 1, alpha = 1)
      )
    )
}
