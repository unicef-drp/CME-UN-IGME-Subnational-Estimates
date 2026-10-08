helper <- file.path("Rcode", "_supporting_scripts", "admin_benchmark_helpers.R")
if (!file.exists(helper)) {
  stop("Missing Admin benchmark helper: ", helper)
}
source(helper)

admin_draws <- list(
  list(years = 2000L, region = "admin1_1", draws = c(0.10, 0.20, 0.30)),
  list(years = 2000L, region = "admin1_2", draws = c(0.20, 0.30, 0.40)),
  list(years = 2001L, region = "admin1_1", draws = c(0.04, 0.05, 0.06)),
  list(years = 2001L, region = "admin1_2", draws = c(0.14, 0.15, 0.16))
)
weights <- data.frame(
  region = c("admin1_1", "admin1_2", "admin1_1", "admin1_2"),
  years = c(2000, 2000, 2001, 2001),
  proportion = c(0.25, 0.75, 0.60, 0.40)
)
igme <- data.frame(
  year = c(2000, 2001),
  OBS_VALUE = c(0.20, 0.10)
)

bench <- compute_admin_benchmark_adjustment(
  country = "Nigeria",
  years = 2000:2001,
  admin_draws = admin_draws,
  admin_weights = weights,
  igme_ests = igme
)

expected_est <- c(0.275, 0.09)
expected_ratio <- c(0.275 / 0.20, 0.09 / 0.10)
if (!isTRUE(all.equal(bench$est, expected_est))) {
  stop("Benchmark estimates should use weighted Admin-1 draw medians.")
}
if (!isTRUE(all.equal(bench$ratio, expected_ratio))) {
  stop("Benchmark ratios should use weighted Admin-1 estimates divided by IGME.")
}

draw_matrix <- matrix(
  c(0.10, 0.20,
    0.30, 0.40),
  nrow = 2,
  byrow = TRUE,
  dimnames = list(NULL, c("admin1_1", "admin1_2"))
)
shuffled_weights <- data.frame(
  region = c("admin1_2", "admin1_1"),
  proportion = c(0.75, 0.25)
)
weighted_draws <- weight_admin_draw_matrix(draw_matrix, shuffled_weights)
if (!isTRUE(all.equal(weighted_draws, c(0.175, 0.375)))) {
  stop("Draw-matrix aggregation should match weights by region name.")
}

main_script <- paste(readLines(file.path("Rcode", "8_10_BB8.R"), warn = FALSE),
                     collapse = "\n")
helper_script <- paste(readLines(file.path("Rcode", "8_10_Run_Unstrat_Admin1_Benchmarks.R"),
                                 warn = FALSE),
                       collapse = "\n")
if (!grepl("compute_admin_benchmark_adjustment", main_script, fixed = TRUE)) {
  stop("8_10_BB8.R should use compute_admin_benchmark_adjustment for Admin-1 benchmarking.")
}
if (!grepl("compute_admin_benchmark_adjustment", helper_script, fixed = TRUE)) {
  stop("Admin-1 benchmark helper script should use compute_admin_benchmark_adjustment.")
}

required_stratified_inputs <- c(
  "admin_draws = bb.res.adm1.strat.nmr$draws.est.overall",
  "admin_weights = weight.adm1.u1",
  "admin_draws = bb.res.adm1.strat.u5$draws.est.overall",
  "admin_weights = weight.adm1.u5"
)
missing_stratified_inputs <- required_stratified_inputs[
  !vapply(
    required_stratified_inputs,
    grepl,
    logical(1),
    x = main_script,
    fixed = TRUE
  )
]
if (length(missing_stratified_inputs) > 0) {
  stop(
    "Stratified Admin-1 benchmarks must use population-weighted Admin-1 ",
    "posterior draws. Missing: ",
    paste(missing_stratified_inputs, collapse = ", ")
  )
}

cat("Admin-1 benchmark ratios use population-weighted Admin-1 posterior draws.\n")
