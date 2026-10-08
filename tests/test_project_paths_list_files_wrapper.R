root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
helper_path <- file.path(root, "Rcode", "_supporting_scripts", "project_paths.R")
source(helper_path)

scratch_dir <- tempfile("list-files-path-helper-")
dir.create(file.path(scratch_dir, "nested"), recursive = TRUE)
on.exit(unlink(scratch_dir, recursive = TRUE), add = TRUE)

path_helper_probe <- data.frame(value = 42)
save(path_helper_probe, file = file.path(scratch_dir, "nested", "probe.rda"))

old_wd <- getwd()
other_dir <- tempfile("list-files-other-wd-")
dir.create(other_dir)
on.exit(unlink(other_dir, recursive = TRUE), add = TRUE)
on.exit(setwd(old_wd), add = TRUE)
setwd(other_dir)

use_path_base(scratch_dir)
stopifnot("probe.rda" %in% list.files("nested"))

cat("list.files() resolves relative paths through project path helper.\n")
