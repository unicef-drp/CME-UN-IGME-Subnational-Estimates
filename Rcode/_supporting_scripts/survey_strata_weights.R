required_survey_strata_columns <- function(mod.dat, columns) {
  missing <- setdiff(columns, names(mod.dat))
  if (length(missing) > 0) {
    stop("Missing required columns for survey-derived strata weights: ",
         paste(missing, collapse = ", "),
         call. = FALSE)
  }
}

annual_strata_frame <- function(urban_fraction, years, region = NULL) {
  if (is.null(region)) {
    out <- data.frame(
      years = years,
      urban = rep(urban_fraction, length(years))
    )
  } else {
    out <- expand.grid(
      region = region,
      years = years,
      KEEP.OUT.ATTRS = FALSE,
      stringsAsFactors = FALSE
    )
    out$urban <- rep(urban_fraction, times = length(years))
  }
  out$rural <- 1 - out$urban
  out
}

cluster_strata_data <- function(mod.dat, region_col = NULL) {
  columns <- c("survey", "cluster", "urban", "v005")
  if (!is.null(region_col)) {
    columns <- c(columns, region_col)
  }
  required_survey_strata_columns(mod.dat, columns)

  cluster_dat <- mod.dat[, columns]
  cluster_dat$urban <- tolower(trimws(as.character(cluster_dat$urban)))
  cluster_dat$v005 <- as.numeric(cluster_dat$v005)
  cluster_dat <- cluster_dat[!is.na(cluster_dat$v005) & cluster_dat$v005 > 0, ]
  cluster_dat <- cluster_dat[cluster_dat$urban %in% c("urban", "rural"), ]

  if (nrow(cluster_dat) == 0) {
    stop("No valid cluster records remain for survey-derived strata weights.",
         call. = FALSE)
  }

  key_cols <- c("survey", "cluster", "urban")
  if (!is.null(region_col)) {
    key_cols <- c(key_cols, region_col)
  }
  stats::aggregate(
    v005 ~ .,
    data = cluster_dat[, c(key_cols, "v005")],
    FUN = mean
  )
}

weighted_urban_fraction <- function(cluster_dat, region_col = NULL,
                                    regions = NULL,
                                    missing_region_fallback = "error",
                                    fallback_value = NULL) {
  missing_region_fallback <- match.arg(missing_region_fallback,
                                       c("error", "national"))
  if (is.null(region_col)) {
    return(sum(cluster_dat$v005[cluster_dat$urban == "urban"]) /
             sum(cluster_dat$v005))
  }

  out <- vapply(regions, function(region) {
    region_dat <- cluster_dat[cluster_dat[[region_col]] == region, ]
    if (nrow(region_dat) == 0) {
      return(NA_real_)
    }
    sum(region_dat$v005[region_dat$urban == "urban"]) / sum(region_dat$v005)
  }, numeric(1))

  if (anyNA(out)) {
    if (identical(missing_region_fallback, "national") &&
        !is.null(fallback_value) &&
        is.finite(fallback_value)) {
      out[is.na(out)] <- fallback_value
      return(unname(out))
    }
    stop("Could not derive strata weights for regions: ",
         paste(regions[is.na(out)], collapse = ", "),
         call. = FALSE)
  }
  unname(out)
}

derive_survey_strata_weights <- function(mod.dat, beg.year, end.proj.year,
                                         admin1.names,
                                         admin2.names = NULL,
                                         missing_region_fallback = "error") {
  missing_region_fallback <- match.arg(missing_region_fallback,
                                       c("error", "national"))
  years <- beg.year:end.proj.year

  national_clusters <- cluster_strata_data(mod.dat)
  natl_urban <- weighted_urban_fraction(national_clusters)
  natl_weights <- annual_strata_frame(natl_urban, years)

  admin1_clusters <- cluster_strata_data(mod.dat, "admin1.char")
  adm1_urban <- weighted_urban_fraction(
    admin1_clusters,
    "admin1.char",
    admin1.names$Internal
  )
  adm1_weights <- annual_strata_frame(adm1_urban, years, admin1.names$Internal)

  weights <- list(
    weight.strata.natl.u1 = natl_weights,
    weight.strata.natl.u5 = natl_weights,
    weight.strata.adm1.u1 = adm1_weights,
    weight.strata.adm1.u5 = adm1_weights,
    weight.strata.adm1.u1.natl = merge(
      expand.grid(region = admin1.names$Internal, years = years,
                  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE),
      natl_weights,
      by = "years"
    ),
    weight.strata.adm1.u5.natl = merge(
      expand.grid(region = admin1.names$Internal, years = years,
                  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE),
      natl_weights,
      by = "years"
    )
  )

  if (!is.null(admin2.names)) {
    admin2_values <- if ("admin2.char" %in% names(mod.dat)) {
      trimws(as.character(mod.dat$admin2.char))
    } else {
      character(0)
    }
    has_admin2_records <- any(
      !is.na(admin2_values) & nzchar(admin2_values)
    )
    if (!has_admin2_records &&
        identical(missing_region_fallback, "national")) {
      adm2_urban <- rep(natl_urban, nrow(admin2.names))
    } else {
      admin2_clusters <- cluster_strata_data(mod.dat, "admin2.char")
      adm2_urban <- weighted_urban_fraction(
        admin2_clusters,
        "admin2.char",
        admin2.names$Internal,
        missing_region_fallback = missing_region_fallback,
        fallback_value = natl_urban
      )
    }
    adm2_weights <- annual_strata_frame(adm2_urban, years,
                                        admin2.names$Internal)
    weights$weight.strata.adm2.u1 <- adm2_weights
    weights$weight.strata.adm2.u5 <- adm2_weights
    weights$weight.strata.adm2.u1.natl <- merge(
      expand.grid(region = admin2.names$Internal, years = years,
                  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE),
      natl_weights,
      by = "years"
    )
    weights$weight.strata.adm2.u5.natl <- merge(
      expand.grid(region = admin2.names$Internal, years = years,
                  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE),
      natl_weights,
      by = "years"
    )
  }

  weights
}

save_survey_strata_weights <- function(weights, res.dir) {
  dir.create(file.path(res.dir, "UR", "U1_fraction"),
             recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(res.dir, "UR", "U5_fraction"),
             recursive = TRUE, showWarnings = FALSE)

  saveRDS(weights$weight.strata.natl.u1,
          file.path(res.dir, "UR", "U1_fraction",
                    "natl_u1_urban_weights.rds"))
  saveRDS(weights$weight.strata.natl.u5,
          file.path(res.dir, "UR", "U5_fraction",
                    "natl_u5_urban_weights.rds"))
  saveRDS(weights$weight.strata.adm1.u1,
          file.path(res.dir, "UR", "U1_fraction",
                    "admin1_u1_urban_weights.rds"))
  saveRDS(weights$weight.strata.adm1.u5,
          file.path(res.dir, "UR", "U5_fraction",
                    "admin1_u5_urban_weights.rds"))

  if (!is.null(weights$weight.strata.adm2.u1)) {
    saveRDS(weights$weight.strata.adm2.u1,
            file.path(res.dir, "UR", "U1_fraction",
                      "admin2_u1_urban_weights.rds"))
    saveRDS(weights$weight.strata.adm2.u5,
            file.path(res.dir, "UR", "U5_fraction",
                      "admin2_u5_urban_weights.rds"))
  }

  invisible(weights)
}
