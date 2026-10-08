source("Rcode/_supporting_scripts/pipeline_runner.R")
source("Rcode/_supporting_scripts/igme_refresh_runner.R")
source("Data/Crisis_Adjustment/apply_myanmar_crisis_adjustment.R")
fixture <- tempfile("myanmar-selection-")
dir.create(file.path(fixture, "Info"), recursive=TRUE)
for (family in c("unstrat", "strat")) {
  jsonlite::write_json(list(final_model=list(strata.model=family, bench.model="bench", time.model="ar1")),
                      file.path(fixture, "Info/Myanmar_general_info.json"), auto_unbox=TRUE)
  specs <- myanmar_crisis_specs(fixture)
  suffix <- if (family == "strat") "strat_u5_bench" else "unstrat_u5_allsurveys_bench"
  expected_files <- paste0("Myanmar_res_",c("adm1","adm2"),"_",suffix,"_crisis.rda")
  stopifnot(identical(basename(vapply(specs, `[[`, "", "output_path")), expected_files),
            identical(basename(igme_refresh_crisis_result_paths(fixture,"Myanmar")), expected_files))
  expected_objects <- paste0("bb.res.",c("adm1","adm2"),".",gsub("_",".",suffix,fixed=TRUE))
  stopifnot(identical(unname(vapply(specs, `[[`, "", "object_name")), expected_objects))
}
cat("Myanmar crisis follows selected model: passed.\n")
