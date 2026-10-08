source(file.path(
  "Data", "Crisis_Adjustment", "apply_myanmar_crisis_adjustment.R"
), local = FALSE)

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
results <- apply_myanmar_crisis_adjustment(
  project_root = project_root,
  write_output = FALSE,
  quiet = TRUE
)

stopifnot(identical(names(results), c("adm1", "adm2")))

for (level_name in names(results)) {
  result <- results[[level_name]]
  audit <- result$allocation_audit
  qx <- result$crisis_qx
  base <- result$base_model
  adjusted <- result$model

  stopifnot(
    identical(sort(unique(qx$years)), 2008L),
    all(qx$crisis_5q0 > 0 & qx$crisis_5q0 < 1),
    identical(result$report_table, report_crisis_table(adjusted))
  )

  allocated <- colSums(audit[c("ed_0_1", "ed_1_5")])
  national <- unique(audit[c("national_ed_0_1", "national_ed_1_5")])
  stopifnot(
    nrow(national) == 1L,
    abs(allocated[["ed_0_1"]] - national$national_ed_0_1) < 1e-8,
    abs(allocated[["ed_1_5"]] - national$national_ed_1_5) < 1e-8
  )

  shifts <- setNames(qx$crisis_5q0, crisis_region_year_key(qx$region, qx$years))
  model_keys <- crisis_region_year_key(base$overall$region, base$overall$years)
  expected_shift <- unname(shifts[model_keys])
  expected_shift[is.na(expected_shift)] <- 0
  stopifnot(max(abs(
    adjusted$overall$median - base$overall$median - expected_shift
  )) < 1e-12)
  stopifnot(
    identical(adjusted$stratified, base$stratified),
    identical(adjusted$draws.est, base$draws.est),
    all(vapply(
      adjusted$draws.est.overall,
      function(entry) all(entry$draws >= 0 & entry$draws < 1),
      logical(1)
    ))
  )
}

stopifnot(
  nrow(results$adm1$allocation_audit) == 2L,
  identical(
    sort(results$adm1$allocation_audit$georepo),
    c("Ayeyarwady", "Yangon")
  ),
  nrow(results$adm2$allocation_audit) == 10L,
  identical(
    sort(unique(results$adm2$allocation_audit$parent)),
    c("Ayeyarwady", "Yangon")
  )
)

message("Myanmar crisis-adjustment tests passed.")
