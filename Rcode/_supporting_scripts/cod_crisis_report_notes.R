cod_crisis_report_notes <- function(home_dir) {
  crisis_dir <- file.path(home_dir, "Data", "Crisis_Adjustment")
  prepared <- new.env(parent = emptyenv())
  load(file.path(crisis_dir, "crisis_COD.rda"), envir = prepared)
  metadata <- prepared$cod_crisis_allocation_metadata
  if (is.null(metadata)) stop("COD crisis allocation metadata is missing.")
  years <- sort(as.integer(metadata$allocated_years))
  notes <- c(
    paste0(
      "The selected subnational U5MR results include the finalized national crisis deaths for ",
      paste(years, collapse = ", "), ". We use the finalized national infant (d0) ",
      "and ages 1-4 (d1-4) crisis-death totals, preserving the age pattern supplied ",
      "in the updated input. For each age group separately, ",
      format(100 * metadata$east_share, trim = TRUE),
      "% is allocated to the historical East and ",
      format(100 * metadata$rest_share, trim = TRUE),
      "% to the Rest. Within each group, deaths are distributed among regions ",
      "in proportion to the corresponding age-specific population. We do not ",
      "recalculate the infant/ages 1-4 split or apply additional relative-risk ",
      "or U5MR multipliers."
    ),
    paste0(
      "The 71% East share refers to all-age excess deaths during January 2003-April ",
      "2004 (Coghlan et al., Lancet 2006, p. 49). The fixed East/Rest split outside ",
      "its source survey period is an allocation ",
      "assumption. Crisis increments are added after benchmarking to the national ",
      "IGME crisis-free series. The crisis increments are deterministic; their ",
      "source uncertainty is not propagated into the model intervals."
    )
  )
  workbook <- readxl::read_xlsx(file.path(crisis_dir, "Crisis_Under5_deaths_2026.xlsx"))
  workbook <- workbook[workbook$ISO3Code == "COD", , drop = FALSE]
  workbook_years <- as.integer(floor(workbook$Year))
  gaps <- setdiff(seq.int(min(years), max(years)), workbook_years)
  if (length(gaps)) {
    notes <- c(notes, paste0(
      "The finalized workbook has no COD row for ", paste(gaps, collapse = ", "),
      "; no crisis increment is applied in those years."
    ))
  }
  national <- function(file) {
    dat <- utils::read.csv(file.path(home_dir, "Data", "IGME", file))
    dat <- dat[dat$ISO.Code == "COD" & tolower(dat$Quantile) == "median", , drop = FALSE]
    if (nrow(dat) != 1L) stop("Expected one national COD median row in ", file)
    dat
  }
  inclusive <- national("igme2026_u5.csv")
  crisis_free <- national("igme2026_u5_nocrisis.csv")
  comparison_years <- seq.int(2000L, max(years))
  columns <- paste0("X", comparison_years, ".5")
  national_increment <- as.numeric(inclusive[columns]) - as.numeric(crisis_free[columns])
  workbook_increment <- workbook[["Crisis rate 0-5"]][match(comparison_years, workbook_years)]
  workbook_increment[is.na(workbook_increment)] <- 0
  if (any(abs(national_increment - workbook_increment) > 0.1)) {
    notes <- c(notes, paste0(
      "National comparison caveat: the supplied crisis-inclusive IGME series does ",
      "not yet reflect the finalized crisis workbook. Its crisis component ",
      "differs from the one applied to these subnational results. Comparisons ",
      "with that national curve during crisis years are therefore provisional."
    ))
  }
  notes
}
