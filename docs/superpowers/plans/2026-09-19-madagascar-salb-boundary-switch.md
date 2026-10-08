# Madagascar SALB Boundary Switch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Madagascar's GADM boundaries with the 2014-2021 validated UN SALB hierarchy and regenerate all boundary-dependent Madagascar outputs.

**Architecture:** A Madagascar-specific preparation script downloads the pinned SALB ArcGIS item and normalizes its single 22-region layer into the pipeline's Admin-0, Admin-1, and Admin-2 layer contract. The country JSON and MICS preprocessing use the normalized SALB schema, while focused tests lock the source identity, temporal period, counts, and hierarchy.

**Tech Stack:** R 4.6.1, `sf`, `jsonlite`, PowerShell, existing R pipeline runner.

---

### Task 1: Lock the SALB configuration contract

**Files:**
- Delete: `tests/test_madagascar_gadm_info.R`
- Create: `tests/test_madagascar_salb_info.R`
- Modify: `tests/test_info_uses_georepo_paths.R`
- Modify: `tests/test_no_legacy_boundary_terms.R`

- [ ] Write tests requiring `../shapeFiles/_alt`, layers `salb_MDG_0/1/2`, labels `NAME_1/2`, and no Madagascar GADM exception.
- [ ] Run the focused tests and confirm they fail against the current GADM configuration.
- [ ] Update `Info/Madagascar_general_info.json` and its archived generator to the SALB path and layers.
- [ ] Run the focused configuration tests and confirm they pass.

### Task 2: Prepare and validate normalized SALB layers

**Files:**
- Create: `Rcode/_script_for_specific_tasks/Madagascar_SALB_Boundaries.R`
- Create: `tests/test_madagascar_salb_boundaries.R`
- Create under ignored data: `Data/shapeFiles/_alt/*`

- [ ] Write a failing test for source constants, 1/6/22 feature counts, parent hierarchy, source-native names, and provenance metadata.
- [ ] Run it and confirm failure because the preparation script and layers do not yet exist.
- [ ] Implement the pinned download, checksum, extraction, validation, dissolve, normalized writes, and metadata write.
- [ ] Run the preparation script, then rerun the focused boundary test and confirm it passes.

### Task 3: Align Madagascar MICS names with SALB

**Files:**
- Modify: `Rcode/_script_for_specific_tasks/MICS_DataProcessing.R`
- Create: `tests/test_madagascar_mics_salb_names.R`

- [ ] Write a failing test requiring source-native SALB region names and prohibiting the GADM-specific recode block.
- [ ] Run it and confirm failure against the current preprocessing code.
- [ ] Remove only the Madagascar GADM-specific recodes and update its source note.
- [ ] Run the focused MICS test and related MICS matching tests.

### Task 4: Remove GADM and verify the preflight contract

**Files:**
- Remove ignored data directory: `Data/Countries/Madagascar/shapeFiles/gadm41_MDG_shp`

- [ ] Verify the resolved removal target is exactly within `Data/Countries/Madagascar/shapeFiles`.
- [ ] Remove the GADM directory authorized by the user.
- [ ] Run `test_madagascar_salb_info.R`, `test_madagascar_salb_boundaries.R`, `test_info_config.R`, `test_info_uses_georepo_paths.R`, `test_no_legacy_boundary_terms.R`, and `test_georepo_shapefile_prep.R`.

### Task 5: Back up and rerun Madagascar

**Files:**
- Create ignored backup and run manifest artifacts under `Results/Madagascar`.
- Replace boundary-dependent ignored outputs under `Data/Countries/Madagascar` and `Results/Madagascar`.

- [ ] Inventory current Madagascar data/results by path, size, and modification time and copy the current boundary-dependent outputs to a timestamped backup.
- [ ] Run `run_country_pipeline(country='Madagascar', mode='production', render_summary=TRUE, project_dir=getwd())` with R 4.6.1.
- [ ] Read the new manifest and stop at the first failed stage if any.
- [ ] Verify the SALB layers, processed survey names, weights, model inventory, dashboard, plots, and final PDF; report the exact validated scope and any blocker.
