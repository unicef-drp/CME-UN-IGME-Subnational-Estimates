files_identical <- function(first, second) {
  if (!file.exists(first) || !file.exists(second)) {
    return(FALSE)
  }
  first_size <- file.info(first)$size
  second_size <- file.info(second)$size
  if (is.na(first_size) || is.na(second_size) || first_size != second_size) {
    return(FALSE)
  }
  identical(unname(tools::md5sum(first)), unname(tools::md5sum(second)))
}

move_tif_safely <- function(source, destination) {
  if (!identical(tolower(tools::file_ext(source)), "tif")) {
    stop("Refusing to migrate a non-TIFF file: ", source, call. = FALSE)
  }
  if (!file.exists(source)) {
    stop("Source TIFF does not exist: ", source, call. = FALSE)
  }

  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(destination)) {
    if (!files_identical(source, destination)) {
      stop(
        "Destination conflict: source and destination TIFFs differ:\n",
        source, "\n", destination,
        call. = FALSE
      )
    }
    if (!file.remove(source)) {
      stop("Could not remove redundant source TIFF: ", source, call. = FALSE)
    }
    return("consolidated")
  }

  if (isTRUE(suppressWarnings(file.rename(source, destination)))) {
    return("moved")
  }

  temporary_destination <- paste0(
    destination, ".partial-", Sys.getpid(), "-", format(Sys.time(), "%Y%m%d%H%M%OS6")
  )
  on.exit(if (file.exists(temporary_destination)) file.remove(temporary_destination),
          add = TRUE)
  if (!file.copy(source, temporary_destination, overwrite = FALSE,
                 copy.mode = TRUE, copy.date = TRUE)) {
    stop("Could not copy TIFF to destination volume: ", source, call. = FALSE)
  }
  if (!files_identical(source, temporary_destination)) {
    stop("Copied TIFF failed content verification: ", source, call. = FALSE)
  }
  if (file.exists(destination) ||
      !isTRUE(suppressWarnings(file.rename(temporary_destination, destination)))) {
    stop("Could not finalize destination TIFF: ", destination, call. = FALSE)
  }
  if (!files_identical(source, destination)) {
    stop("Final destination TIFF failed content verification: ", destination,
         call. = FALSE)
  }
  if (!file.remove(source)) {
    stop("Could not remove verified source TIFF: ", source, call. = FALSE)
  }
  "moved"
}

empty_migration_result <- function() {
  data.frame(
    country = character(),
    raster_type = character(),
    source = character(),
    destination = character(),
    status = character(),
    stringsAsFactors = FALSE
  )
}

migrate_worldpop_tifs <- function(countries_root, worldpop_home, quiet = FALSE) {
  if (!dir.exists(countries_root)) {
    stop("Country data root does not exist: ", countries_root, call. = FALSE)
  }

  countries <- sort(list.dirs(countries_root, recursive = FALSE, full.names = FALSE))
  layouts <- list(
    raw = c(source = "worldpop", destination = "Global1_2000_2020"),
    population = c(source = "Population", destination = "Population")
  )
  rows <- list()

  for (country in countries) {
    for (raster_type in names(layouts)) {
      layout <- layouts[[raster_type]]
      source_dir <- file.path(countries_root, country, unname(layout[["source"]]))
      if (!dir.exists(source_dir)) {
        next
      }
      sources <- sort(list.files(
        source_dir,
        pattern = "\\.tif$",
        full.names = TRUE,
        recursive = FALSE,
        ignore.case = TRUE
      ))
      for (source in sources) {
        destination <- file.path(
          worldpop_home,
          unname(layout[["destination"]]),
          country,
          basename(source)
        )
        status <- move_tif_safely(source, destination)
        if (!quiet) {
          message(status, ": ", source, " -> ", destination)
        }
        rows[[length(rows) + 1L]] <- data.frame(
          country = country,
          raster_type = raster_type,
          source = source,
          destination = destination,
          status = status,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(rows) == 0L) {
    return(empty_migration_result())
  }
  do.call(rbind, rows)
}

if (sys.nframe() == 0L) {
  repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  helper <- file.path(repo, "Rcode", "_supporting_scripts", "project_paths.R")
  if (!file.exists(helper)) {
    stop("Run this script from the UN-Subnational-Estimates repository root.",
         call. = FALSE)
  }
  source(helper)
  migration <- migrate_worldpop_tifs(
    country_data_root(project_home()),
    worldpop_data_home()
  )
  message("Migrated or consolidated ", nrow(migration), " TIFF files.")
}
