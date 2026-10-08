# Restore missing geographic fields only; never alter survey or mortality data.
restore_cluster_admin2_from_gps <- function(data, polygons, label, name_map) {
  required <- c('cluster', 'survey', 'LONGNUM', 'LATNUM')
  added <- c('admin2', 'admin2.char', 'admin2.name')
  if (!all(required %in% names(data)) || !nrow(data) ||
      any(added %in% names(data))) {
    stop('Expected nonempty cluster data with GPS and no existing Admin-2 fields.')
  }
  if (!label %in% names(polygons) ||
      !identical(as.character(polygons[[label]]), as.character(name_map$GeoRepo)) ||
      !identical(as.character(name_map$Internal), paste0('admin2_', seq_len(nrow(polygons))))) {
    stop('Admin-2 polygons and saved name-map ordering disagree.')
  }
  if (any(!is.finite(data$LONGNUM) | !is.finite(data$LATNUM)) ||
      any(abs(data$LONGNUM) > 180 | abs(data$LATNUM) > 90) ||
      any(data$LONGNUM == 0 & data$LATNUM == 0)) {
    stop('Cannot restore Admin-2 assignments without valid GPS coordinates.')
  }
  clusters <- unique(data[required])
  key <- function(d) paste(d$survey, d$cluster, sep='|')
  if (anyDuplicated(key(clusters))) stop('A survey cluster has inconsistent coordinates.')
  points <- sf::st_as_sf(clusters, coords=c('LONGNUM','LATNUM'), crs=4326)
  points <- sf::st_transform(points, sf::st_crs(polygons))
  within <- sf::st_within(points, polygons)
  if (any(lengths(within) > 1L)) stop('Ambiguous overlapping Admin-2 polygons.')
  index <- vapply(within, function(x) if (length(x)) x[[1]] else NA_integer_, integer(1))
  outside <- is.na(index)
  if (any(outside)) index[outside] <- sf::st_nearest_feature(points[outside,], polygons)
  if (anyNA(index)) stop('Unresolved Admin-2 assignments.')
  rows <- match(key(data), key(clusters))
  result <- data
  result$admin2 <- index[rows]
  result$admin2.char <- as.character(name_map$Internal[result$admin2])
  result$admin2.name <- as.character(name_map$GeoRepo[result$admin2])
  stopifnot(identical(result[names(data)], data))
  list(data=result, clusters=nrow(clusters), outside_clusters=sum(outside),
       regions=length(unique(index)))
}
