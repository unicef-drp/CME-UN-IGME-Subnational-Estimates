recode_admin1_merge_names <- function(names, admin1_name_merges) {
  if (is.null(admin1_name_merges) || length(admin1_name_merges) == 0) {
    return(names)
  }

  recoded <- as.character(names)
  for (target_name in names(admin1_name_merges)) {
    source_names <- unname(unlist(admin1_name_merges[[target_name]]))
    recoded[recoded %in% source_names] <- target_name
  }

  recoded
}

dissolve_admin1_by_name <- function(poly.adm1, poly.label.adm1) {
  admin1_order <- unique(poly.adm1[[poly.label.adm1]])
  crs <- sf::st_crs(poly.adm1)

  dissolved <- lapply(admin1_order, function(admin1_name) {
    rows <- which(poly.adm1[[poly.label.adm1]] == admin1_name)
    attrs <- sf::st_drop_geometry(poly.adm1[rows[1], , drop = FALSE])
    geom <- sf::st_union(sf::st_geometry(poly.adm1[rows, , drop = FALSE]))
    geom <- sf::st_make_valid(geom)

    if (!inherits(geom, "sfc")) {
      geom <- sf::st_sfc(geom, crs = crs)
    } else {
      sf::st_crs(geom) <- crs
    }

    sf::st_sf(attrs, geometry = geom)
  })

  do.call(rbind, dissolved)
}

apply_admin1_name_merges <- function(poly.adm1,
                                     poly.adm2 = NULL,
                                     poly.label.adm1,
                                     admin1_name_merges = NULL) {
  if (is.null(admin1_name_merges) || length(admin1_name_merges) == 0) {
    return(list(poly.adm1 = poly.adm1, poly.adm2 = poly.adm2))
  }
  if (!(poly.label.adm1 %in% names(poly.adm1))) {
    stop("Cannot merge admin1 names because ", poly.label.adm1,
         " is not in poly.adm1.", call. = FALSE)
  }

  original_admin1_names <- unique(as.character(poly.adm1[[poly.label.adm1]]))
  source_names <- unique(unlist(admin1_name_merges, use.names = FALSE))
  missing_sources <- setdiff(source_names, original_admin1_names)
  target_names <- names(admin1_name_merges)
  already_merged <- target_names[target_names %in% original_admin1_names]
  if (length(missing_sources) > 0 && length(already_merged) == 0) {
    stop("Cannot merge admin1 names because these source names are missing: ",
         paste(missing_sources, collapse = ", "), call. = FALSE)
  }

  poly.adm1[[poly.label.adm1]] <- recode_admin1_merge_names(
    poly.adm1[[poly.label.adm1]],
    admin1_name_merges
  )
  poly.adm1 <- dissolve_admin1_by_name(poly.adm1, poly.label.adm1)

  if (!is.null(poly.adm2) && poly.label.adm1 %in% names(poly.adm2)) {
    poly.adm2[[poly.label.adm1]] <- recode_admin1_merge_names(
      poly.adm2[[poly.label.adm1]],
      admin1_name_merges
    )
  }

  list(poly.adm1 = poly.adm1, poly.adm2 = poly.adm2)
}
