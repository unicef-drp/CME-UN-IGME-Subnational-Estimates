repair_utf8_text <- function(labels) {
  labels <- as.character(labels)
  invalid_utf8 <- !is.na(labels) & !validUTF8(labels)
  labels[invalid_utf8] <- iconv(
    labels[invalid_utf8],
    from = "latin1",
    to = "UTF-8",
    sub = ""
  )
  enc2utf8(labels)
}

repair_utf8_columns <- function(data) {
  for (column in names(data)) {
    if (is.factor(data[[column]])) {
      original <- data[[column]]
      data[[column]] <- factor(
        repair_utf8_text(as.character(original)),
        levels = unique(repair_utf8_text(levels(original))),
        ordered = is.ordered(original)
      )
    } else if (is.character(data[[column]])) {
      data[[column]] <- repair_utf8_text(data[[column]])
    }
  }
  data
}

normalize_urban_frame_admin_label <- function(labels) {
  labels <- repair_utf8_text(labels)
  labels <- iconv(labels, from = "UTF-8", to = "ASCII//TRANSLIT", sub = "")
  labels <- tolower(trimws(labels))
  gsub("[^a-z0-9]+", "", labels)
}

expand_urban_frame_to_current_admin <- function(
    frame,
    admin1_labels,
    parent_map = NULL) {
  if (!is.data.frame(frame) || ncol(frame) < 2L) {
    stop("Urban-frame input must contain region and proportion columns.", call. = FALSE)
  }

  frame_keys <- normalize_urban_frame_admin_label(frame[[1]])
  admin_keys <- normalize_urban_frame_admin_label(admin1_labels)
  desired_frame_keys <- admin_keys

  if (!is.null(parent_map) && NROW(parent_map) > 0L) {
    parent_map <- as.data.frame(parent_map, stringsAsFactors = FALSE)
    required <- c("admin1", "frame_region")
    if (!all(required %in% names(parent_map))) {
      stop(
        "urban_frame_admin1_parent_map must contain admin1 and frame_region.",
        call. = FALSE
      )
    }
    map_admin_keys <- normalize_urban_frame_admin_label(parent_map$admin1)
    map_frame_keys <- normalize_urban_frame_admin_label(parent_map$frame_region)
    map_index <- match(admin_keys, map_admin_keys)
    mapped <- !is.na(map_index)
    desired_frame_keys[mapped] <- map_frame_keys[map_index[mapped]]
  }

  frame_index <- match(desired_frame_keys, frame_keys)
  if (any(is.na(frame_index))) {
    stop(
      "Could not match urban-frame rows to current admin1 names: ",
      paste(as.character(admin1_labels)[is.na(frame_index)], collapse = ", "),
      call. = FALSE
    )
  }

  expanded <- frame[frame_index, , drop = FALSE]
  rownames(expanded) <- NULL
  expanded[[1]] <- admin_keys
  expanded
}
