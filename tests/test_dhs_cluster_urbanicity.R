source(file.path(
  "Rcode", "_supporting_scripts", "dhs_admin1_recode.R"
))

fixture <- data.frame(
  v001 = c(rep(476, 8), rep(500, 4)),
  caseid = c(
    rep("476-urban-1", 3),
    rep("476-urban-2", 2),
    rep("476-urban-3", 2),
    "476-rural-1",
    rep("500-urban-1", 2),
    rep("500-urban-2", 2)
  ),
  v025 = factor(
    c(rep("urban", 7), "rural", rep("urban", 4)),
    levels = c("urban", "rural")
  )
)

fixed <- harmonize_dhs_cluster_urbanicity(fixture)
stopifnot(
  all(as.character(fixed$data$v025[fixed$data$v001 == 476]) == "urban"),
  all(as.character(fixed$data$v025[fixed$data$v001 == 500]) == "urban"),
  nrow(fixed$repairs) == 1L,
  identical(fixed$repairs$cluster, 476),
  identical(fixed$repairs$selected, "urban"),
  identical(fixed$repairs$respondents, 4L)
)

tie_fixture <- data.frame(
  v001 = c(1, 1),
  caseid = c("urban-woman", "rural-woman"),
  v025 = factor(c("urban", "rural"), levels = c("urban", "rural"))
)
tie_error <- tryCatch(
  {
    harmonize_dhs_cluster_urbanicity(tie_fixture)
    NULL
  },
  error = identity
)
if (is.null(tie_error) ||
    !grepl("tied respondent counts", conditionMessage(tie_error), fixed = TRUE)) {
  stop("Tied DHS cluster urbanicity must fail closed.")
}

cat("DHS cluster urbanicity is harmonized by unique-respondent mode.\n")
