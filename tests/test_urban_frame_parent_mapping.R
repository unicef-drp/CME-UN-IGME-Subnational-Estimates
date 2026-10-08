env <- new.env(parent = baseenv())
sys.source(
  file.path("Rcode", "_supporting_scripts", "urban_frame_matching.R"),
  envir = env
)

frame <- data.frame(
  region = c(
    "Kayes",
    paste0("S", intToUtf8(0x00e9), "gou"),
    "Tombouctou",
    "Gao"
  ),
  urban_prop = c(0.14, 0.09, 0.13, 0.21)
)
latin1_label <- function(bytes) rawToChar(as.raw(bytes))
admin1 <- c(
  "Kayes",
  latin1_label(c(0x53, 0xe9, 0x67, 0x6f, 0x75)),
  "Timbuktu",
  "Taoudenni",
  latin1_label(c(0x4d, 0xe9, 0x6e, 0x61, 0x6b, 0x61))
)
parent_map <- data.frame(
  admin1 = c("Timbuktu", "Taoudenni", "Menaka"),
  frame_region = c("Tombouctou", "Tombouctou", "Gao")
)

repaired <- env$repair_utf8_text(c(
  latin1_label(c(0x4d, 0xe9, 0x6e, 0x61, 0x6b, 0x61)),
  latin1_label(c(0x44, 0x69, 0x6f, 0xef, 0x6c, 0x61))
))
stopifnot(all(validUTF8(repaired)))
expected_repaired <- c(
  paste0("M", intToUtf8(0x00e9), "naka"),
  paste0("Dio", intToUtf8(0x00ef), "la")
)
stopifnot(all(repaired == expected_repaired))

factor_input <- data.frame(
  age = factor(c("0", "1-11"), levels = c("0", "1-11")),
  region = factor(c(
    latin1_label(c(0x4d, 0xe9, 0x6e, 0x61, 0x6b, 0x61)),
    "Kayes"
  ))
)
factor_repaired <- env$repair_utf8_columns(factor_input)
stopifnot(is.factor(factor_repaired$age))
stopifnot(identical(levels(factor_repaired$age), c("0", "1-11")))
stopifnot(is.factor(factor_repaired$region))
stopifnot(all(validUTF8(levels(factor_repaired$region))))

expanded <- env$expand_urban_frame_to_current_admin(
  frame,
  admin1,
  parent_map
)

stopifnot(nrow(expanded) == length(admin1))
stopifnot(all(validUTF8(expanded$region)))
stopifnot(identical(
  expanded$urban_prop,
  c(0.14, 0.09, 0.13, 0.13, 0.21)
))

cat("Historic urban-frame regions expand to current admin-1 boundaries.\n")
