normalize_guinea_bissau_admin1 <- function(x) {
  x <- trimws(as.character(x))
  key <- tolower(iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT"))
  normalized <- c(
    "bafata" = "Bafat\u00e1",
    "biombo" = "Biombo",
    "sabis" = "Bissau",
    "sab" = "Bissau",
    "bissau" = "Bissau",
    "bijagos/bubaque" = "Bolama",
    "bolama/bijagos" = "Bolama",
    "bolama" = "Bolama",
    "cacheu" = "Cacheu",
    "gabu" = "Gab\u00fa",
    "oio" = "Oio",
    "quinara" = "Quinara",
    "tombali" = "Tombali"
  )
  unname(normalized[key])
}

guinea_bissau_label_names <- function(x) {
  labels <- attr(x, "labels")
  if (is.null(labels)) {
    stop("Expected a labelled Guinea-Bissau region variable.", call. = FALSE)
  }
  names(labels)[match(as.numeric(x), as.numeric(labels))]
}

get_guinea_bissau_admin1_names <- function(
    boundary_dir = file.path("Data", "shapeFiles", "georepo_GNB_shp")) {
  if (!dir.exists(boundary_dir)) {
    stop("Guinea-Bissau GeoRepo boundary directory is missing: ",
         boundary_dir, call. = FALSE)
  }
  poly_adm1 <- sf::st_read(
    boundary_dir,
    layer = "georepo_GNB_1",
    quiet = TRUE
  )
  sort(as.character(poly_adm1$NAME_1))
}

validate_guinea_bissau_admin1 <- function(admin1.name, boundary_dir) {
  expected <- get_guinea_bissau_admin1_names(boundary_dir)
  observed <- sort(unique(admin1.name))
  unmatched <- setdiff(observed, expected)
  missing <- setdiff(expected, observed)
  if (length(unmatched) > 0L || length(missing) > 0L) {
    stop(
      "Guinea-Bissau MICS Admin-1 names do not match GeoRepo. Unmatched: ",
      paste(unmatched, collapse = ", "), "; missing: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
}

build_guinea_bissau_mics_tmp <- function(
    bh, survey_year, output_file, qa, boundary_dir) {
  validate_guinea_bissau_admin1(bh$admin1.name, boundary_dir)

  dat.tmp <- SUMMER::getBirths(
    data = bh,
    surveyyear = survey_year,
    variables = c(
      "cluster", "dob", "age_at_death", "interview_cmc", "alive",
      "v005", "urban", "admin1.name"
    ),
    strata = c("urban", "admin1.name"),
    dob = "dob",
    alive = "alive",
    age = "age_at_death",
    date.interview = "interview_cmc",
    age.truncate = 24,
    year.cut = seq(2000, survey_year + 1, 1),
    compact.by = c("cluster", "v005", "urban", "admin1.name"),
    compact = TRUE
  )

  dat.tmp <- dat.tmp[, c(
    "cluster", "age", "time", "total", "died", "v005", "urban",
    "admin1.name"
  )]
  names(dat.tmp) <- c(
    "cluster", "age", "years", "total", "Y", "v005", "urban",
    "admin1.name"
  )
  dat.tmp$survey <- survey_year
  attr(dat.tmp, "guinea_bissau_qa") <- qa

  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  save(dat.tmp, file = output_file)
  invisible(dat.tmp)
}

prepare_guinea_bissau_mics_2010 <- function(
    source_file = file.path(
      "Data", "MICS", "Guinea-Bissau", "2010", "GuineaBissau2010.sav"
    ),
    output_file = file.path(
      "Data", "MICS", "Guinea-Bissau", "gnb.2010.tmp.rda"
    ),
    boundary_dir = file.path("Data", "shapeFiles", "georepo_GNB_shp")) {
  source <- haven::read_sav(source_file)

  b5 <- as.numeric(source$B5)
  b7 <- as.numeric(source$B7)
  dead <- b5 == 0
  missing_death_age <- dead & (is.na(b7) | b7 < 0)

  admin1.name <- normalize_guinea_bissau_admin1(
    guinea_bissau_label_names(source$V101)
  )
  urban <- ifelse(
    as.numeric(source$V102) == 1, "urban",
    ifelse(as.numeric(source$V102) == 2, "rural", NA_character_)
  )
  alive <- ifelse(b5 == 1, "yes", ifelse(dead, "no", NA_character_))

  usable <- !missing_death_age &
    !is.na(alive) & !is.na(urban) & !is.na(admin1.name) &
    is.finite(as.numeric(source$V021)) &
    is.finite(as.numeric(source$B3)) &
    is.finite(as.numeric(source$V008)) &
    is.finite(as.numeric(source$V005)) & as.numeric(source$V005) > 0

  age_at_death <- b7
  age_at_death[dead & b7 >= 0 & b7 < 1] <- 0

  bh <- data.frame(
    cluster = as.numeric(source$V021[usable]),
    dob = as.numeric(source$B3[usable]),
    age_at_death = age_at_death[usable],
    interview_cmc = as.numeric(source$V008[usable]),
    alive = alive[usable],
    v005 = as.numeric(source$V005[usable]),
    urban = urban[usable],
    admin1.name = admin1.name[usable],
    stringsAsFactors = FALSE
  )

  qa <- list(
    source_birth_rows = as.integer(nrow(source)),
    usable_birth_rows = as.integer(nrow(bh)),
    excluded_missing_death_age = as.integer(sum(missing_death_age)),
    clusters = as.integer(length(unique(bh$cluster))),
    admin1_areas = as.integer(length(unique(bh$admin1.name)))
  )
  build_guinea_bissau_mics_tmp(
    bh, 2010, output_file, qa, boundary_dir
  )
}

prepare_guinea_bissau_mics_2014 <- function(
    source_file = file.path(
      "Data", "MICS", "Guinea-Bissau", "2014", "bh.sav"
    ),
    output_file = file.path(
      "Data", "MICS", "Guinea-Bissau", "gnb.2014.tmp.rda"
    ),
    boundary_dir = file.path("Data", "shapeFiles", "georepo_GNB_shp")) {
  source <- haven::read_sav(source_file)

  b5 <- as.numeric(source$BH5)
  b7 <- as.numeric(source$BH9C)
  dead <- b5 == 2
  missing_death_age <- dead & (is.na(b7) | b7 < 0)

  admin1.name <- normalize_guinea_bissau_admin1(
    guinea_bissau_label_names(source$HH7)
  )
  urban <- ifelse(
    as.numeric(source$HH6) == 1, "urban",
    ifelse(as.numeric(source$HH6) == 2, "rural", NA_character_)
  )
  alive <- ifelse(b5 == 1, "yes", ifelse(dead, "no", NA_character_))

  usable <- !missing_death_age &
    !is.na(alive) & !is.na(urban) & !is.na(admin1.name) &
    is.finite(as.numeric(source$HH1)) &
    is.finite(as.numeric(source$BH4C)) &
    is.finite(as.numeric(source$WDOI)) &
    is.finite(as.numeric(source$wmweight)) & as.numeric(source$wmweight) > 0

  bh <- data.frame(
    cluster = as.numeric(source$HH1[usable]),
    dob = as.numeric(source$BH4C[usable]),
    age_at_death = b7[usable],
    interview_cmc = as.numeric(source$WDOI[usable]),
    alive = alive[usable],
    v005 = as.numeric(source$wmweight[usable]),
    urban = urban[usable],
    admin1.name = admin1.name[usable],
    stringsAsFactors = FALSE
  )

  qa <- list(
    source_birth_rows = as.integer(nrow(source)),
    usable_birth_rows = as.integer(nrow(bh)),
    excluded_missing_death_age = as.integer(sum(missing_death_age)),
    clusters = as.integer(length(unique(bh$cluster))),
    admin1_areas = as.integer(length(unique(bh$admin1.name)))
  )
  build_guinea_bissau_mics_tmp(
    bh, 2014, output_file, qa, boundary_dir
  )
}

if (sys.nframe() == 0L) {
  prepare_guinea_bissau_mics_2010()
  prepare_guinea_bissau_mics_2014()
}
