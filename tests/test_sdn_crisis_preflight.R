source('Rcode/_supporting_scripts/pipeline_runner.R')
source('Rcode/_supporting_scripts/project_paths.R')
e <- new.env(parent=globalenv())
sys.source('Rcode/_supporting_scripts/igme_refresh_runner.R',envir=e)
p <- e$igme_refresh_crisis_preflight(project_home(),'Sudan')
stopifnot(all(file.exists(p$scripts)),all(file.exists(p$inputs)),
  any(grepl('prepare_sdn_darfur.R$',p$scripts)),
  any(grepl('apply_sdn_crisis_adjustment.R$',p$scripts)),
  any(grepl('sdn_2025_state_weights.csv$',p$inputs)),
  any(grepl('sdn_2025_state_weights_source.json$',p$inputs)),
  !any(grepl('crisis_SDN.rda$',p$inputs)))
cfg <- jsonlite::read_json('Info/Sudan_general_info.json',simplifyVector=TRUE)
cfg$doCrisisAdj <- TRUE
e$igme_refresh_benchmark_contract <- function(...) stop('REACHED_BENCHMARK_CONTRACT')
msg <- tryCatch(e$preflight_igme_refresh(project_home(),'Sudan',list(values=cfg)),error=conditionMessage)
stopifnot(identical(msg,'REACHED_BENCHMARK_CONTRACT'))
# An Admin-1-only exception is specific to Sudan's supported implementation.
msg <- tryCatch(e$preflight_igme_refresh(project_home(),'DR_Congo',list(values=cfg)),error=conditionMessage)
stopifnot(grepl('requires Admin-2',msg,fixed=TRUE))
cat('Sudan Admin-1 crisis preflight contract passed.\n')
