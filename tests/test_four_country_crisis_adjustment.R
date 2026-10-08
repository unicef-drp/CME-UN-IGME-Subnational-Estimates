script_path <- file.path(
  "Data", "Crisis_Adjustment", "apply_four_country_crisis_adjustments.R"
)
source(script_path, local = FALSE)

synthetic_haiti_admin2 <- data.frame(
  georepo = c("Port-au-Prince", "Delmas", "Cap-Haitien", "Jacmel"),
  parent = c("West", "West", "North", "South-East"),
  years = rep(2010L, 4L),
  weight_u1 = c(0.10, 0.30, 0.25, 0.35),
  weight_u5 = c(0.20, 0.20, 0.25, 0.35),
  national_ed_0_1 = rep(100, 4L),
  national_ed_1_5 = rep(200, 4L),
  stringsAsFactors = FALSE
)
synthetic_haiti_allocation <- allocate_haiti_admin2_crisis(
  synthetic_haiti_admin2
)
synthetic_west <- synthetic_haiti_allocation$parent == "West"
stopifnot(
  identical(synthetic_haiti_allocation$ed_0_1, c(25, 75, 0, 0)),
  identical(synthetic_haiti_allocation$ed_1_5, c(100, 100, 0, 0)),
  sum(synthetic_haiti_allocation$ed_0_1[synthetic_west]) == 100,
  sum(synthetic_haiti_allocation$ed_1_5[synthetic_west]) == 200
)

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
results <- apply_four_country_crisis_adjustments(
  project_root = project_root,
  write_output = FALSE,
  quiet = TRUE
)

expected <- list(
  Guinea = list(years = 2014:2015, rows = c(adm1 = 16L, adm2 = 76L)),
  Haiti = list(years = 2010L, rows = c(adm1 = 10L, adm2 = 140L)),
  Liberia = list(years = 2014:2015, rows = c(adm1 = 30L, adm2 = 272L)),
  Sierra_Leone = list(years = 2014:2015, rows = c(adm1 = 10L, adm2 = 32L))
)

stopifnot(identical(names(results), names(expected)))

for (country in names(expected)) {
  stopifnot(identical(names(results[[country]]), names(expected[[country]]$rows)))
  for (level_name in names(expected[[country]]$rows)) {
    result <- results[[country]][[level_name]]
    audit <- result$allocation_audit
    qx <- result$crisis_qx
    base <- result$base_model
    adjusted <- result$model

    stopifnot(
      nrow(audit) == expected[[country]]$rows[[level_name]],
      nrow(qx) == expected[[country]]$rows[[level_name]],
      identical(sort(unique(qx$years)), expected[[country]]$years),
      all(is.finite(qx$crisis_5q0)),
      all(qx$crisis_5q0 >= 0 & qx$crisis_5q0 < 1)
    )

    national <- unique(audit[c("years", "national_ed_0_1", "national_ed_1_5")])
    allocated <- aggregate(
      cbind(ed_0_1, ed_1_5) ~ years,
      data = audit,
      FUN = sum
    )
    national <- national[match(allocated$years, national$years), , drop = FALSE]
    stopifnot(
      max(abs(allocated$ed_0_1 - national$national_ed_0_1)) < 1e-8,
      max(abs(allocated$ed_1_5 - national$national_ed_1_5)) < 1e-8
    )

    shift <- setNames(
      qx$crisis_5q0,
      crisis_region_year_key(qx$region, qx$years)
    )
    keys <- crisis_region_year_key(base$overall$region, base$overall$years)
    expected_shift <- unname(shift[keys])
    expected_shift[is.na(expected_shift)] <- 0
    for (column in c("median", "mean", "lower", "upper")) {
      stopifnot(max(abs(
        adjusted$overall[[column]] - base$overall[[column]] - expected_shift
      )) < 1e-12)
    }
    stopifnot(
      identical(adjusted$overall$variance, base$overall$variance),
      identical(result$report_table, report_crisis_table(adjusted))
    )
  }
}

guinea_admin2 <- results$Guinea$adm2$allocation_audit
conakry <- guinea_admin2[guinea_admin2$parent == "Conakry", , drop = FALSE]
stopifnot(
  identical(sort(unique(conakry$georepo)), sort(c(
    "Dixinn", "Kaloum", "Matam", "Matoto", "Ratoma"
  ))),
  all(conakry$ed_0_1 > 0),
  all(conakry$ed_1_5 > 0)
)

haiti <- results$Haiti$adm1$allocation_audit
stopifnot(
  all(haiti$ed_0_1[haiti$georepo != "West"] == 0),
  all(haiti$ed_1_5[haiti$georepo != "West"] == 0),
  all(haiti$ed_0_1[haiti$georepo == "West"] > 0),
  all(haiti$ed_1_5[haiti$georepo == "West"] > 0)
)

haiti_admin2 <- results$Haiti$adm2$allocation_audit
haiti_west_children <- normalize_crisis_region_name(haiti_admin2$parent) %in%
  c("west", "ouest")
stopifnot(
  sum(haiti_west_children) == 20L,
  all(haiti_admin2$ed_0_1[!haiti_west_children] == 0),
  all(haiti_admin2$ed_1_5[!haiti_west_children] == 0),
  all(haiti_admin2$ed_0_1[haiti_west_children] > 0),
  all(haiti_admin2$ed_1_5[haiti_west_children] > 0)
)

liberia_admin2 <- results$Liberia$adm2$allocation_audit
liberia_admin1 <- results$Liberia$adm1$allocation_audit
for (year in expected$Liberia$years) {
  child <- aggregate(
    cbind(ed_0_1, ed_1_5) ~ parent,
    data = liberia_admin2[liberia_admin2$years == year, , drop = FALSE],
    FUN = sum
  )
  parent <- liberia_admin1[liberia_admin1$years == year, , drop = FALSE]
  parent <- parent[match(child$parent, parent$georepo), , drop = FALSE]
  stopifnot(
    max(abs(child$ed_0_1 - parent$ed_0_1)) < 1e-8,
    max(abs(child$ed_1_5 - parent$ed_1_5)) < 1e-8
  )
}

message("Four-country crisis-adjustment dry-run tests passed.")
