worldpop_raster_file_ok <- function(file) {
  length(file) == 1L &&
    !is.na(file) &&
    file.exists(file) &&
    is.finite(file.info(file)$size) &&
    file.info(file)$size > 0 &&
    tryCatch({
      raster <- suppressWarnings(terra::rast(file))
      terra::nlyr(raster) > 0L
    }, error = function(e) FALSE)
}

worldpop_global2_url <- function(year, iso0, filename) {
  sprintf(
    paste0(
      "https://data.worldpop.org/GIS/AgeSex_structures/",
      "Global_2015_2030/R2025A/%s/%s/v1/1km_ua/constrained/%s"
    ),
    as.integer(year),
    toupper(iso0),
    filename
  )
}

download_worldpop_raster <- function(url, target, download_file,
                                     raster_ok = worldpop_raster_file_ok,
                                     timeout_seconds = 200000) {
  timeout_seconds <- as.numeric(timeout_seconds)
  if (length(timeout_seconds) != 1L || !is.finite(timeout_seconds) ||
      timeout_seconds <= 0) {
    stop("WorldPop download timeout must be a positive number of seconds.",
         call. = FALSE)
  }

  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile(
    pattern = paste0(basename(target), "."),
    tmpdir = dirname(target),
    fileext = ".download"
  )
  on.exit(unlink(temporary), add = TRUE)

  old_timeout <- getOption("timeout")
  options(timeout = max(c(old_timeout, timeout_seconds), na.rm = TRUE))
  on.exit(options(timeout = old_timeout), add = TRUE)

  download_warning <- NULL
  status <- tryCatch(
    withCallingHandlers(
      download_file(url, temporary, mode = "wb", quiet = TRUE),
      warning = function(w) {
        download_warning <<- conditionMessage(w)
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      stop(
        "Could not download WorldPop raster: ", url, "\n",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
  status_ok <- length(status) == 1L &&
    is.numeric(status) &&
    is.finite(status) &&
    status == 0
  if (!status_ok) {
    status_label <- if (length(status) == 1L) as.character(status) else "unknown"
    stop(
      "WorldPop download failed with status ", status_label, ": ", url,
      if (!is.null(download_warning)) paste0("\n", download_warning) else "",
      call. = FALSE
    )
  }
  if (!raster_ok(temporary)) {
    stop("Downloaded WorldPop raster is unreadable: ", url, call. = FALSE)
  }

  if (file.exists(target) && unlink(target) != 0L) {
    stop("Could not replace unreadable WorldPop raster: ", target,
         call. = FALSE)
  }
  if (!file.rename(temporary, target)) {
    stop("Could not move downloaded WorldPop raster into place: ", target,
         call. = FALSE)
  }
  invisible(target)
}

ensure_worldpop_population_inputs <- function(
    country,
    iso0,
    years,
    root = worldpop_data_home(),
    download_file = utils::download.file,
    raster_ok = worldpop_raster_file_ok) {
  years <- sort(unique(as.integer(years)))
  country <- as.character(country)
  iso0 <- toupper(as.character(iso0))

  if (length(country) != 1L || is.na(country) || !nzchar(country)) {
    stop("Provide one WorldPop country name.", call. = FALSE)
  }
  if (length(iso0) != 1L || is.na(iso0) || !grepl("^[A-Z]{3}$", iso0)) {
    stop("WorldPop ISO code must contain three letters.", call. = FALSE)
  }
  if (length(years) == 0L || anyNA(years)) {
    stop("WorldPop years must be finite integers.", call. = FALSE)
  }
  if (!is.function(download_file) || !is.function(raster_ok)) {
    stop("WorldPop download and validation handlers must be functions.",
         call. = FALSE)
  }

  input_grid <- expand.grid(
    sex = c("f", "m"),
    age = 0:1,
    stringsAsFactors = FALSE
  )
  manifest <- vector("list", length(years))

  for (year_index in seq_along(years)) {
    year <- years[year_index]
    paths <- mapply(
      function(sex, age) {
        worldpop_population_age_sex_file(
          year = year,
          sex = sex,
          age = age,
          country = country,
          iso0 = iso0,
          root = root
        )
      },
      input_grid$sex,
      input_grid$age,
      USE.NAMES = FALSE
    )
    actions <- rep("reused", length(paths))
    missing <- !vapply(paths, raster_ok, logical(1))

    if (year <= 2014L && any(missing)) {
      archive <- file.path(
        root, "Global1_2000_2020_aligned", paste0(year, ".zip")
      )
      if (!file.exists(archive) || file.info(archive)$size <= 0) {
        stop("Missing WorldPop Global1 archive: ", archive, call. = FALSE)
      }

      members <- paste(
        year,
        iso0,
        basename(paths[missing]),
        sep = "/"
      )
      archive_members <- tryCatch(
        utils::unzip(archive, list = TRUE)$Name,
        error = function(e) {
          stop(
            "Could not read WorldPop Global1 archive: ", archive, "\n",
            conditionMessage(e),
            call. = FALSE
          )
        }
      )
      archive_members <- gsub("\\\\", "/", archive_members)
      absent_members <- setdiff(members, archive_members)
      if (length(absent_members) > 0L) {
        stop(
          "WorldPop Global1 archive does not contain: ",
          paste(absent_members, collapse = ", "),
          call. = FALSE
        )
      }

      extract_root <- file.path(
        root,
        "Global1_2000_2020_aligned",
        paste0(country, "_extracted")
      )
      dir.create(extract_root, recursive = TRUE, showWarnings = FALSE)
      message("Extracting ", year, "/", iso0,
              " from WorldPop Global1 archive")
      tryCatch(
        utils::unzip(
          archive,
          files = members,
          exdir = extract_root,
          overwrite = TRUE
        ),
        error = function(e) {
          stop(
            "Could not extract WorldPop Global1 archive: ", archive, "\n",
            conditionMessage(e),
            call. = FALSE
          )
        }
      )
      unreadable <- paths[missing][
        !vapply(paths[missing], raster_ok, logical(1))
      ]
      if (length(unreadable) > 0L) {
        stop(
          "Extracted WorldPop raster is missing or unreadable: ",
          paste(unreadable, collapse = ", "),
          call. = FALSE
        )
      }
      actions[missing] <- "extracted"
    }

    if (year >= 2015L && any(missing)) {
      for (input_index in which(missing)) {
        target <- paths[input_index]
        url <- worldpop_global2_url(
          year = year,
          iso0 = iso0,
          filename = basename(target)
        )
        message("Downloading missing WorldPop Global2 raster: ",
                basename(target))
        download_worldpop_raster(
          url = url,
          target = target,
          download_file = download_file,
          raster_ok = raster_ok
        )
        actions[input_index] <- "downloaded"
      }
    }

    manifest[[year_index]] <- data.frame(
      year = rep(year, nrow(input_grid)),
      sex = input_grid$sex,
      age = input_grid$age,
      source = worldpop_population_source_name(year),
      action = actions,
      path = paths,
      stringsAsFactors = FALSE
    )
  }

  manifest <- do.call(rbind, manifest)
  rownames(manifest) <- NULL
  invisible(manifest)
}
