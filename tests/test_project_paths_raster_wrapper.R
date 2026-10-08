root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
helper_path <- file.path(root, "Rcode", "_supporting_scripts", "project_paths.R")
source(helper_path)

scratch_dir <- tempfile("raster-path-helper-")
dir.create(scratch_dir)
on.exit(unlink(scratch_dir, recursive = TRUE), add = TRUE)

test_raster <- raster::raster(nrows = 1, ncols = 1, xmn = 0, xmx = 1,
                              ymn = 0, ymx = 1)
raster::values(test_raster) <- 7
raster::writeRaster(test_raster, filename = file.path(scratch_dir, "tiny.tif"),
                    overwrite = TRUE)

old_wd <- getwd()
other_dir <- tempfile("raster-other-wd-")
dir.create(other_dir)
on.exit(unlink(other_dir, recursive = TRUE), add = TRUE)
on.exit(setwd(old_wd), add = TRUE)
setwd(other_dir)

use_path_base(scratch_dir)
loaded_raster <- raster("tiny.tif")
stopifnot(identical(as.numeric(raster::values(loaded_raster)), 7))

cat("raster() resolves relative paths through project path helper.\n")
