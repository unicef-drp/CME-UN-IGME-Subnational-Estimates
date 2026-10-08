# Portable Source Repository and Git Ignore Design

## Goal

Keep the Git repository portable and reproducible while preventing SharePoint or
OneDrive from synchronizing pipeline inputs, generated results, and disposable
working files. A user should be able to clone or download the repository into a
nonsynced local directory, supply the required input data separately, run the
pipeline locally, and copy only approved deliverables back to SharePoint.

## Repository contents to track

Git will continue to track the source bundle needed to understand, configure,
test, and run the pipeline:

- pipeline and supporting scripts under `Rcode/`;
- country configuration files under `Info/`, especially
  `Info/*_general_info.json`;
- automated checks under `tests/`;
- documentation under `docs/`, `README.md`, and workflow reference files;
- the RStudio project file and repository configuration such as `.gitignore`.

Country JSON files are treated as source configuration, not input data. They are
required for a reproducible local run and must remain trackable.

## Files to ignore

The root `.gitignore` will ignore these directory-owned artifact classes:

- `/Data/` for survey inputs, boundaries, population rasters, and derived
  country data;
- `/Results/` for model objects, figures, dashboards, logs, manifests, and final
  deliverables;
- `/outputs/` for standalone generated products;
- `/tmp/` for review renders, extracts, diagnostics, and other scratch work.

It will also ignore local application state and accidentally generated artifacts
outside those directories:

- RStudio, R session, Quarto, and plot-device state;
- temporary Codex driver files such as `/.codex_tmp_*`;
- root-level generated PDF and HTML artifacts;
- common render intermediates such as logs, LaTeX auxiliary files, knitted
  Markdown, and generated resource directories;
- credential and environment files, including `rdhs.json`, `.Renviron`, and
  local `.env` files, while allowing a future `.env.example` template.

The design will not use a global source-extension allowlist. An allowlist would
be fragile, could silently exclude a required JSON configuration or test fixture,
and would require frequent maintenance as the project evolves.

## Local execution workflow

1. Clone or download the Git repository to a directory outside OneDrive or a
   synced SharePoint library.
2. Supply the required `Data/` inputs separately by copying the relevant country
   inputs into the local clone. Git is not the transport for survey microdata,
   rasters, shapefiles, or other large or sensitive inputs.
3. Run the pipeline from the local clone. `Data/`, `Results/`, `outputs/`, and
   `tmp/` then remain local and nonsynced.
4. Inspect and validate the results locally.
5. Copy only approved deliverables and, when needed, manifests to their intended
   SharePoint destination.

The existing `UN_SUBNATIONAL_HOME` and `UN_SUBNATIONAL_WORLDPOP_HOME` overrides
remain available for locating a local project clone and external WorldPop data.
No pipeline methodology or output format changes are part of this work.

## Existing Git index

At design time, `git ls-files` reports no tracked files under `Data/`, `Results/`,
`outputs/`, or `tmp/`. Therefore the implementation will not run
`git rm --cached` or otherwise remove indexed files. Existing unrelated worktree
changes will be preserved.

## Verification

Because this is a configuration-only change, verification will use Git's actual
ignore engine rather than application-level tests:

- create or identify representative paths for ignored inputs, outputs, scratch,
  render intermediates, and credentials;
- confirm them with `git check-ignore -v`;
- confirm representative R scripts, tests, country JSON files, documentation,
  and the project file are not ignored;
- verify that no currently tracked source file becomes ignored;
- inspect the final `.gitignore` diff for accidental broad patterns.

Verification must not create persistent test data in the repository. Any
temporary probe files will be placed in a verified local scratch location or
removed immediately after the checks.

## Non-goals

- Removing or relocating existing data and results from SharePoint.
- Deleting historical pipeline artifacts.
- Tracking input data with Git LFS.
- Changing pipeline models, survey scope, boundaries, or deliverable formats.
- Automating publication of local results back to SharePoint.
