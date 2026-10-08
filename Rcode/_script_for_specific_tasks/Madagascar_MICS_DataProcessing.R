USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))

madagascar_mics_project_home <- function() {
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

  normalizePath(
    file.path(
      dir_SP,
      "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main"
    ),
    winslash = "/",
    mustWork = TRUE
  )
}

prepare_madagascar_mics_2018 <- function(
    project_dir = madagascar_mics_project_home(),
    input_file = file.path(
      project_dir, "Data", "MICS", "Madagascar", "mdg_2018_bh.sav"
    ),
    output_file = file.path(
      project_dir, "Data", "MICS", "Madagascar", "mdg.2018.tmp.rda"
    )) {
  required_packages <- c("haven", "dplyr", "stringr", "SUMMER")
  missing <- required_packages[
    !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) > 0L) {
    stop(
      "Missing required package(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  if (!file.exists(input_file)) {
    stop("Madagascar 2018 MICS birth-history file is missing: ",
         input_file, call. = FALSE)
  }

  bh <- haven::read_sav(input_file)
  required_columns <- c("HH1", "BH4C", "BH5", "BH9C", "HH6", "HH7", "WDOI", "wmweight")
  missing_columns <- setdiff(required_columns, names(bh))
  if (length(missing_columns) > 0L) {
    stop(
      "Madagascar 2018 MICS data is missing column(s): ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  bh <- dplyr::select(bh, dplyr::all_of(required_columns))
  bh <- dplyr::mutate(
    bh,
    urban = ifelse(HH6 == 1, "urban", ifelse(HH6 == 2, "rural", NA)),
    alive = ifelse(BH5 == 1, "yes", ifelse(BH5 == 2, "no", NA))
  )

  hh7_labels <- attr(bh$HH7, "labels")
  if (is.null(hh7_labels) || length(hh7_labels) == 0L ||
      is.null(names(hh7_labels))) {
    stop("Madagascar 2018 MICS HH7 has no labelled regions.", call. = FALSE)
  }
  bh$admin2.name <- NA_character_
  for (i in seq_along(hh7_labels)) {
    bh$admin2.name[bh$HH7 == hh7_labels[[i]]] <- names(hh7_labels)[[i]]
  }
  bh$admin2.name <- stringr::str_to_title(tolower(bh$admin2.name))

  expected_names <- sort(c(
    "Alaotra Mangoro", "Amoron'i Mania", "Analamanga", "Analanjirofo",
    "Androy", "Anosy", "Atsimo Andrefana", "Atsimo Atsinanana",
    "Atsinanana", "Betsiboka", "Boeny", "Bongolava", "Diana",
    "Haute Matsiatra", "Ihorombe", "Itasy", "Melaky", "Menabe",
    "Sava", "Sofia", "Vakinankaratra", "Vatovavy Fitovinany"
  ))
  observed_names <- sort(unique(stats::na.omit(bh$admin2.name)))
  if (!identical(observed_names, expected_names)) {
    stop(
      "Madagascar 2018 MICS region labels do not match the 2014-2021 SALB names. ",
      "Observed: ", paste(observed_names, collapse = ", "),
      call. = FALSE
    )
  }

  births <- SUMMER::getBirths(
    data = bh,
    surveyyear = 2018,
    variables = c(
      "HH1", "BH4C", "BH9C", "WDOI", "alive", "wmweight",
      "urban", "admin2.name"
    ),
    strata = c("urban", "admin2.name"),
    dob = "BH4C",
    alive = "alive",
    age = "BH9C",
    date.interview = "WDOI",
    age.truncate = 24,
    year.cut = seq(2000, 2019, 1),
    compact.by = c("HH1", "wmweight", "urban", "admin2.name"),
    compact = TRUE
  )

  dat.tmp <- births[, c(
    "HH1", "age", "time", "total", "died", "wmweight", "urban",
    "admin2.name"
  )]
  names(dat.tmp) <- c(
    "cluster", "age", "years", "total", "Y", "v005", "urban",
    "admin2.name"
  )
  dat.tmp$survey <- 2018

  output_dir <- dirname(output_file)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  save(dat.tmp, file = output_file)

  check_env <- new.env(parent = emptyenv())
  load(output_file, envir = check_env)
  saved <- get("dat.tmp", envir = check_env)
  saved_names <- sort(unique(as.character(saved$admin2.name)))
  if (!identical(saved_names, expected_names)) {
    stop("Saved Madagascar MICS intermediate failed SALB name verification.",
         call. = FALSE)
  }

  message("Prepared Madagascar 2018 MICS intermediate: ", output_file)
  invisible(list(
    output_file = normalizePath(output_file, winslash = "/", mustWork = TRUE),
    rows = nrow(saved),
    admin2_names = saved_names
  ))
}

main <- prepare_madagascar_mics_2018

if (sys.nframe() == 0L) {
  main()
}
