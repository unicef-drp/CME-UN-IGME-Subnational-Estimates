helper <- file.path(
  "Rcode", "_supporting_scripts", "final_admin2_recovery.R"
)
stopifnot(file.exists(helper))

env <- new.env(parent = baseenv())
sys.source(helper, envir = env)

strat <- env$final_admin2_recovery_plan(list(
  strata.model = "strat", bench.model = "bench"
))
stopifnot(
  identical(strat$branch, "strat"),
  identical(strat$data_scope, "same_frame"),
  identical(strat$stubs$nmr$base, "adm2_strat_nmr"),
  identical(strat$stubs$nmr$bench, "adm2_strat_nmr_bench"),
  identical(strat$stubs$u5$base, "adm2_strat_u5"),
  identical(strat$stubs$u5$bench, "adm2_strat_u5_bench")
)

unstrat <- env$final_admin2_recovery_plan(list(
  strata.model = "unstrat", bench.model = "bench"
))
stopifnot(
  identical(unstrat$branch, "unstrat"),
  identical(unstrat$data_scope, "all_surveys"),
  identical(
    unstrat$stubs$nmr$bench,
    "adm2_unstrat_nmr_allsurveys_bench"
  ),
  identical(
    unstrat$stubs$u5$bench,
    "adm2_unstrat_u5_allsurveys_bench"
  )
)

bad_unbenchmarked <- try(
  env$final_admin2_recovery_plan(list(
    strata.model = "strat", bench.model = "unbench"
  )),
  silent = TRUE
)
stopifnot(inherits(bad_unbenchmarked, "try-error"))

bad_branch <- try(
  env$final_admin2_recovery_plan(list(
    strata.model = "unknown", bench.model = "bench"
  )),
  silent = TRUE
)
stopifnot(inherits(bad_branch, "try-error"))

main_text <- paste(
  readLines("Rcode/8_10_BB8.R", warn = FALSE),
  collapse = "\n"
)
stopifnot(
  grepl(
    'Sys.getenv("BB8_FINAL_ADMIN2_ONLY", "0")',
    main_text,
    fixed = TRUE
  ),
  grepl("run_final_admin2_only", main_text, fixed = TRUE)
)

outputs <- env$final_admin2_expected_outputs(
  country = "Testland",
  res_dir = "Results/Testland",
  plan = strat
)
stopifnot(
  length(outputs) == 10L,
  any(grepl(
    "Testland_res_adm2_strat_nmr_bench.rda$",
    outputs
  )),
  any(grepl(
    "Testland_res_adm2_strat_u5_bench.rda$",
    outputs
  )),
  all(grepl("Betabinomial", outputs, fixed = TRUE))
)

valid_names <- data.frame(
  GeoRepo = c("A", "B"),
  Internal = c("admin2_1", "admin2_2")
)
valid_matrix <- matrix(c(0, 1, 1, 0), 2, 2)
dimnames(valid_matrix) <- list(
  valid_names$Internal,
  valid_names$Internal
)
valid_weights <- data.frame(
  region = rep(valid_names$Internal, each = 2),
  years = rep(2024:2025, times = 2),
  proportion = 0.5
)
stopifnot(isTRUE(env$validate_final_admin2_inputs(
  admin2_names = valid_names,
  admin2_matrix = valid_matrix,
  weight_u1 = valid_weights,
  weight_u5 = valid_weights,
  years = 2024:2025
)))

missing_region <- valid_weights[
  valid_weights$region != "admin2_2",
  ,
  drop = FALSE
]
stopifnot(inherits(try(
  env$validate_final_admin2_inputs(
    valid_names,
    valid_matrix,
    missing_region,
    valid_weights,
    2024:2025
  ),
  silent = TRUE
), "try-error"))

stopifnot(identical(
  env$final_admin2_benchmark_path(
    res_dir = "Results/Testland",
    metric_dir = "NMR",
    base_stub = unstrat$stubs$nmr$base
  ),
  file.path(
    "Results/Testland", "Betabinomial", "NMR",
    "adm2_unstrat_nmr_benchmarks.rda"
  )
))

benchmark_file <- tempfile(fileext = ".rda")
on.exit(unlink(benchmark_file, force = TRUE), add = TRUE)
env$save_final_admin2_benchmark_adjustment(
  data.frame(country = "Testland", years = 2025, ratio = 1),
  benchmark_file
)
benchmark_env <- new.env(parent = emptyenv())
benchmark_objects <- load(benchmark_file, envir = benchmark_env)
stopifnot(
  identical(benchmark_objects, "bench.adj"),
  is.data.frame(benchmark_env$bench.adj),
  identical(benchmark_env$bench.adj$ratio, 1)
)
