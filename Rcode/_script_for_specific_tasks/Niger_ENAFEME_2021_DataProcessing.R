# Prepare Niger ENAFEME 2021 as a non-geospatial MICS-like pipeline input.

niger_enafeme_project_home <- function() {
  configured_home <- Sys.getenv("UN_SUBNATIONAL_HOME", unset = "")
  if (nzchar(configured_home)) {
    return(normalizePath(configured_home, winslash = "/", mustWork = TRUE))
  }

  frames <- sys.frames()
  for (frame in rev(frames)) {
    if (!is.null(frame$ofile)) {
      return(normalizePath(
        file.path(dirname(frame$ofile), "..", ".."),
        winslash = "/",
        mustWork = TRUE
      ))
    }
  }

  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

normalize_niger_enafeme_admin1 <- function(x) {
  x <- trimws(as.character(x))
  x[x == "Tillabéri"] <- "Tillaberi"
  x
}

prepare_niger_enafeme_2021 <- function(
    source_file = file.path(
      niger_enafeme_project_home(),
      "Data", "MICS", "Niger", "2021", "NIBR70BFL.sav"
    ),
    boundary_dir = file.path(
      niger_enafeme_project_home(),
      "Data", "shapeFiles", "georepo_NER_shp"
    ),
    output_file = file.path(
      niger_enafeme_project_home(),
      "Data", "MICS", "Niger", "ner.2021.tmp.rda"
    )) {
  required_packages <- c("haven", "sf", "SUMMER")
  missing_packages <- required_packages[
    !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing_packages) > 0) {
    stop("Missing required package(s): ",
         paste(missing_packages, collapse = ", "), call. = FALSE)
  }
  if (!file.exists(source_file)) {
    stop("Niger ENAFEME birth-recode file not found: ", source_file,
         call. = FALSE)
  }
  if (!dir.exists(boundary_dir)) {
    stop("Niger GeoRepo boundary directory not found: ", boundary_dir,
         call. = FALSE)
  }

  births <- haven::read_sav(source_file)
  names(births) <- tolower(names(births))
  required_vars <- c(
    "v001", "v005", "v008", "v024", "v025",
    "b3", "b5", "b7"
  )
  missing_vars <- setdiff(required_vars, names(births))
  if (length(missing_vars) > 0) {
    stop("Niger ENAFEME source is missing: ",
         paste(missing_vars, collapse = ", "), call. = FALSE)
  }

  source_birth_rows <- nrow(births)
  future_birth <- !is.na(births$b3) & !is.na(births$v008) &
    as.numeric(births$b3) > as.numeric(births$v008)
  excluded_future_births <- sum(future_birth)

  region_labels <- attr(births$v024, "labels")
  if (is.null(region_labels)) {
    stop("Niger ENAFEME V024 has no region value labels.", call. = FALSE)
  }
  births$admin1.name <- names(region_labels)[
    match(as.numeric(births$v024), as.numeric(region_labels))
  ]
  births$admin1.name <- normalize_niger_enafeme_admin1(
    births$admin1.name
  )

  poly_adm1 <- sf::st_read(
    boundary_dir, "georepo_NER_1", quiet = TRUE,
    options = "ENCODING=UTF-8"
  )
  georepo_admin1 <- sort(unique(as.character(poly_adm1$NAME_1)))
  source_admin1 <- sort(unique(stats::na.omit(births$admin1.name)))
  unmatched_admin1 <- setdiff(source_admin1, georepo_admin1)
  if (length(unmatched_admin1) > 0) {
    stop("Niger ENAFEME Admin-1 names do not match GeoRepo: ",
         paste(unmatched_admin1, collapse = ", "), call. = FALSE)
  }

  births$b5 <- factor(
    ifelse(
      as.numeric(births$b5) == 1, "yes",
      ifelse(as.numeric(births$b5) == 0, "no", NA_character_)
    ),
    levels = c("yes", "no")
  )
  births$v025 <- factor(
    ifelse(
      as.numeric(births$v025) == 1, "urban",
      ifelse(as.numeric(births$v025) == 2, "rural", NA_character_)
    ),
    levels = c("urban", "rural")
  )

  usable <- !future_birth & !is.na(births$b3) & !is.na(births$v008) &
    !is.na(births$b5) & !is.na(births$v025) &
    !is.na(births$v001) & !is.na(births$v005) &
    is.finite(as.numeric(births$v005)) & as.numeric(births$v005) > 0 &
    !is.na(births$admin1.name)
  births <- births[usable, , drop = FALSE]

  cluster_frame <- unique(data.frame(
    cluster = as.numeric(births$v001),
    urban = as.character(births$v025),
    stringsAsFactors = FALSE
  ))
  if (anyDuplicated(cluster_frame$cluster)) {
    stop("A Niger ENAFEME cluster maps to multiple residences.",
         call. = FALSE)
  }

  dat.tmp <- SUMMER::getBirths(
    data = births,
    surveyyear = 2021,
    variables = c(
      "v001", "b3", "b7", "v008", "b5", "v005", "v025",
      "admin1.name"
    ),
    strata = c("v025", "admin1.name"),
    dob = "b3",
    alive = "b5",
    age = "b7",
    date.interview = "v008",
    age.truncate = 24,
    year.cut = seq(2000, 2022, 1),
    compact.by = c("v001", "v005", "v025", "admin1.name"),
    compact = TRUE
  )
  dat.tmp <- dat.tmp[, c(
    "v001", "age", "time", "total", "died", "v005", "v025",
    "admin1.name"
  )]
  names(dat.tmp) <- c(
    "cluster", "age", "years", "total", "Y", "v005", "urban",
    "admin1.name"
  )
  dat.tmp$LONGNUM <- NA_real_
  dat.tmp$LATNUM <- NA_real_
  dat.tmp$survey <- 2021
  attr(dat.tmp, "enafeme_qa") <- list(
    source_birth_rows = as.integer(source_birth_rows),
    usable_birth_rows = as.integer(nrow(births)),
    excluded_future_births = as.integer(excluded_future_births),
    clusters = as.integer(nrow(cluster_frame)),
    urban_clusters = as.integer(sum(cluster_frame$urban == "urban")),
    rural_clusters = as.integer(sum(cluster_frame$urban == "rural")),
    sampling_frame_year = 2012L
  )

  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  save(dat.tmp, file = output_file)
  message("Saved Niger ENAFEME 2021 tmp data: ", output_file)
  message("Excluded future-dated births: ", excluded_future_births)
  invisible(dat.tmp)
}

if (sys.nframe() == 0) {
  prepare_niger_enafeme_2021()
}
