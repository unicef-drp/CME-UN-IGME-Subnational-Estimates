require_columns <- function(data, columns, data_name) {
  missing_columns <- setdiff(columns, names(data))
  if (length(missing_columns) > 0) {
    stop(data_name, " is missing required columns: ",
         paste(missing_columns, collapse = ", "), call. = FALSE)
  }
}

make_mics_admin2_key <- function(mod.dat) {
  if (is.null(mod.dat)) {
    stop("Cannot build the MICS admin2 key because no DHS mod.dat is available.",
         call. = FALSE)
  }

  key_columns <- c(
    "admin1", "admin2", "admin1.char", "admin2.char",
    "admin1.name", "admin2.name"
  )
  require_columns(mod.dat, key_columns, "mod.dat")

  admin.key <- unique(mod.dat[key_columns])
  admin.key$admin2.name <- as.character(admin.key$admin2.name)
  admin.key <- admin.key[
    !is.na(admin.key$admin2.name) & nzchar(trimws(admin.key$admin2.name)),
    ,
    drop = FALSE
  ]

  if (nrow(admin.key) == 0) {
    stop("Cannot build the MICS admin2 key because mod.dat has no admin2 names.",
         call. = FALSE)
  }

  duplicate_names <- unique(admin.key$admin2.name[duplicated(admin.key$admin2.name)])
  if (length(duplicate_names) > 0) {
    stop("admin2.name is not unique in the MICS admin2 key: ",
         paste(duplicate_names, collapse = ", "), call. = FALSE)
  }

  rownames(admin.key) <- NULL
  admin.key
}

make_mics_admin1_key <- function(mod.dat) {
  if (is.null(mod.dat)) {
    stop("Cannot build the MICS admin1 key because no DHS mod.dat is available.",
         call. = FALSE)
  }

  key_columns <- c("admin1", "admin1.char", "admin1.name")
  require_columns(mod.dat, key_columns, "mod.dat")

  admin.key <- unique(mod.dat[key_columns])
  admin.key$admin1.name <- as.character(admin.key$admin1.name)
  admin.key <- admin.key[
    !is.na(admin.key$admin1.name) & nzchar(trimws(admin.key$admin1.name)),
    ,
    drop = FALSE
  ]

  if (nrow(admin.key) == 0) {
    stop("Cannot build the MICS admin1 key because mod.dat has no admin1 names.",
         call. = FALSE)
  }

  duplicate_names <- unique(admin.key$admin1.name[duplicated(admin.key$admin1.name)])
  if (length(duplicate_names) > 0) {
    stop("admin1.name is not unique in the MICS admin1 key: ",
         paste(duplicate_names, collapse = ", "), call. = FALSE)
  }

  rownames(admin.key) <- NULL
  admin.key
}

make_optional_mics_admin_keys <- function(mod.dat, poly.adm1,
                                           poly.label.adm1) {
  if (!is.character(poly.label.adm1) || length(poly.label.adm1) != 1L ||
      is.na(poly.label.adm1) || !nzchar(poly.label.adm1) ||
      !(poly.label.adm1 %in% names(poly.adm1))) {
    stop("poly.label.adm1 must identify one column in poly.adm1.",
         call. = FALSE)
  }

  if (!is.null(mod.dat)) {
    return(list(
      admin1 = make_mics_admin1_key(mod.dat),
      admin2 = make_mics_admin2_key(mod.dat)
    ))
  }

  admin1_names <- as.character(poly.adm1[[poly.label.adm1]])
  invalid_names <- is.na(admin1_names) | !nzchar(trimws(admin1_names))
  if (any(invalid_names)) {
    stop("Cannot build the boundary-derived MICS admin1 key because ",
         poly.label.adm1, " contains missing or empty names.", call. = FALSE)
  }
  duplicate_names <- unique(admin1_names[duplicated(admin1_names)])
  if (length(duplicate_names) > 0) {
    stop("admin1.name is not unique in the boundary-derived MICS key: ",
         paste(duplicate_names, collapse = ", "), call. = FALSE)
  }

  list(
    admin1 = data.frame(
      admin1 = seq_along(admin1_names),
      admin1.char = paste0("admin1_", seq_along(admin1_names)),
      admin1.name = admin1_names,
      stringsAsFactors = FALSE
    ),
    admin2 = NULL
  )
}

normalize_mics_admin_name <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- gsub("[^[:alnum:]]+", " ", x)
  gsub("\\s+", " ", trimws(x))
}

match_mics_admin_names <- function(values, key_values, admin_level, mics_file) {
  match_index <- match(values, key_values)

  unmatched <- is.na(match_index)
  if (any(unmatched)) {
    normalized_key <- normalize_mics_admin_name(key_values)
    duplicate_normalized <- unique(normalized_key[duplicated(normalized_key)])

    if (length(duplicate_normalized) == 0) {
      normalized_values <- normalize_mics_admin_name(values[unmatched])
      match_index[unmatched] <- match(normalized_values, normalized_key)
      unmatched <- is.na(match_index)
    }
  }

  if (any(unmatched)) {
    stop("MICS ", admin_level, " names in ", mics_file,
         " were not found in the ", admin_level, " key: ",
         paste(unique(values[unmatched]), collapse = ", "), call. = FALSE)
  }

  match_index
}

validate_mics_geospatial_admin2 <- function(dat.tmp,
                                             admin1_names,
                                             admin2_names,
                                             mics_file = "MICS geospatial data") {
  required_columns <- c(
    "cluster", "urban", "LONGNUM", "LATNUM", "admin1", "admin2",
    "admin1.char", "admin2.char", "admin1.name", "admin2.name"
  )
  require_columns(dat.tmp, required_columns, "dat.tmp")

  admin1_names <- as.character(admin1_names)
  admin2_names <- as.character(admin2_names)
  admin1_index <- suppressWarnings(as.integer(dat.tmp$admin1))
  admin2_index <- suppressWarnings(as.integer(dat.tmp$admin2))

  invalid_admin1 <- is.na(admin1_index) |
    admin1_index < 1L | admin1_index > length(admin1_names)
  invalid_admin2 <- is.na(admin2_index) |
    admin2_index < 1L | admin2_index > length(admin2_names)
  if (any(invalid_admin1)) {
    stop("MICS Admin-1 indices in ", mics_file,
         " are missing or outside the boundary range.", call. = FALSE)
  }
  if (any(invalid_admin2)) {
    stop("MICS Admin-2 indices in ", mics_file,
         " are missing or outside the boundary range.", call. = FALSE)
  }

  expected_admin1 <- admin1_names[admin1_index]
  expected_admin2 <- admin2_names[admin2_index]
  admin1_mismatch <- normalize_mics_admin_name(dat.tmp$admin1.name) !=
    normalize_mics_admin_name(expected_admin1)
  admin2_mismatch <- normalize_mics_admin_name(dat.tmp$admin2.name) !=
    normalize_mics_admin_name(expected_admin2)
  if (any(is.na(admin1_mismatch) | admin1_mismatch)) {
    bad_names <- unique(as.character(
      dat.tmp$admin1.name[is.na(admin1_mismatch) | admin1_mismatch]
    ))
    stop("MICS Admin-1 names in ", mics_file,
         " do not match their boundary indices: ",
         paste(bad_names, collapse = ", "), call. = FALSE)
  }
  if (any(is.na(admin2_mismatch) | admin2_mismatch)) {
    bad_names <- unique(as.character(
      dat.tmp$admin2.name[is.na(admin2_mismatch) | admin2_mismatch]
    ))
    stop("MICS Admin-2 names in ", mics_file,
         " do not match their boundary indices: ",
         paste(bad_names, collapse = ", "), call. = FALSE)
  }

  invalid_coordinates <- !is.finite(dat.tmp$LONGNUM) |
    !is.finite(dat.tmp$LATNUM) |
    (dat.tmp$LONGNUM == 0 & dat.tmp$LATNUM == 0)
  if (any(invalid_coordinates)) {
    stop("MICS geospatial coordinates are missing or invalid in ",
         mics_file, ".", call. = FALSE)
  }

  dat.tmp$urban <- as.character(dat.tmp$urban)
  if (any(is.na(dat.tmp$urban) | !nzchar(trimws(dat.tmp$urban)))) {
    stop("MICS urban/rural values are missing in ", mics_file, ".",
         call. = FALSE)
  }

  dat.tmp$admin1 <- admin1_index
  dat.tmp$admin2 <- admin2_index
  dat.tmp$admin1.char <- paste0("admin1_", admin1_index)
  dat.tmp$admin2.char <- paste0("admin2_", admin2_index)
  dat.tmp$admin1.name <- expected_admin1
  dat.tmp$admin2.name <- expected_admin2
  dat.tmp$strata <- paste(admin2_index, dat.tmp$urban, sep = ":")
  dat.tmp$survey.type <- "MICS"
  dat.tmp
}

attach_mics_admin1_key <- function(dat.tmp, admin.key, mics_file = "MICS data") {
  require_columns(dat.tmp, c("admin1.name", "urban"), "dat.tmp")
  require_columns(admin.key, c("admin1", "admin1.char", "admin1.name"),
                  "admin.key")

  dat.tmp$admin1.name <- as.character(dat.tmp$admin1.name)
  dat.tmp$urban <- as.character(dat.tmp$urban)

  missing_admin1 <- is.na(dat.tmp$admin1.name) |
    !nzchar(trimws(dat.tmp$admin1.name))
  if (any(missing_admin1)) {
    stop("MICS admin1 names are missing in ", mics_file, ".",
         call. = FALSE)
  }

  duplicate_names <- unique(admin.key$admin1.name[duplicated(admin.key$admin1.name)])
  if (length(duplicate_names) > 0) {
    stop("admin1.name is not unique in the MICS admin1 key: ",
         paste(duplicate_names, collapse = ", "), call. = FALSE)
  }

  missing_urban <- is.na(dat.tmp$urban) | !nzchar(trimws(dat.tmp$urban))
  if (any(missing_urban)) {
    stop("MICS urban/rural values are missing in ", mics_file, ".",
         call. = FALSE)
  }

  match_index <- match_mics_admin_names(
    dat.tmp$admin1.name, admin.key$admin1.name, "admin1", mics_file
  )
  dat.tmp$admin1.name <- admin.key$admin1.name[match_index]
  dat.tmp$admin1 <- admin.key$admin1[match_index]
  dat.tmp$admin1.char <- admin.key$admin1.char[match_index]
  dat.tmp$admin2 <- NA_integer_
  dat.tmp$admin2.char <- NA_character_
  dat.tmp$admin2.name <- NA_character_
  dat.tmp$strata <- paste(dat.tmp$admin1, dat.tmp$urban, sep = ":")
  dat.tmp$LONGNUM <- NA_real_
  dat.tmp$LATNUM <- NA_real_
  dat.tmp$survey.type <- "MICS"

  dat.tmp
}

attach_mics_admin2_key <- function(dat.tmp, admin.key, mics_file = "MICS data") {
  require_columns(dat.tmp, c("admin2.name", "urban"), "dat.tmp")
  require_columns(
    admin.key,
    c("admin1", "admin2", "admin1.char", "admin2.char",
      "admin1.name", "admin2.name"),
    "admin.key"
  )

  dat.tmp$admin2.name <- as.character(dat.tmp$admin2.name)
  dat.tmp$urban <- as.character(dat.tmp$urban)

  missing_admin2 <- is.na(dat.tmp$admin2.name) |
    !nzchar(trimws(dat.tmp$admin2.name))
  if (any(missing_admin2)) {
    stop("MICS admin2 names are missing in ", mics_file, ".",
         call. = FALSE)
  }

  duplicate_names <- unique(admin.key$admin2.name[duplicated(admin.key$admin2.name)])
  if (length(duplicate_names) > 0) {
    stop("admin2.name is not unique in the MICS admin2 key: ",
         paste(duplicate_names, collapse = ", "), call. = FALSE)
  }

  unmatched <- setdiff(unique(dat.tmp$admin2.name), admin.key$admin2.name)
  if (length(unmatched) > 0) {
    stop("MICS admin2 names in ", mics_file,
         " were not found in the admin2 key: ",
         paste(unmatched, collapse = ", "), call. = FALSE)
  }

  missing_urban <- is.na(dat.tmp$urban) | !nzchar(trimws(dat.tmp$urban))
  if (any(missing_urban)) {
    stop("MICS urban/rural values are missing in ", mics_file, ".",
         call. = FALSE)
  }

  match_index <- match(dat.tmp$admin2.name, admin.key$admin2.name)
  dat.tmp$admin1.name <- admin.key$admin1.name[match_index]
  dat.tmp$admin1 <- admin.key$admin1[match_index]
  dat.tmp$admin1.char <- admin.key$admin1.char[match_index]
  dat.tmp$admin2 <- admin.key$admin2[match_index]
  dat.tmp$admin2.char <- admin.key$admin2.char[match_index]
  dat.tmp$strata <- paste(dat.tmp$admin2, dat.tmp$urban, sep = ":")
  dat.tmp$LONGNUM <- NA_real_
  dat.tmp$LATNUM <- NA_real_
  dat.tmp$survey.type <- "MICS"

  dat.tmp
}
