# Malawi crisis application and final output refresh

Goal: Apply the user-authorized FAO/WFP district beneficiary proxy to national 2001 infant and ages 1-4 crisis deaths, and refresh all Malawi final consumers.

Architecture: Reuse prepare_mwi_fao_proxy.R and the established deterministic conversion/application helpers. Preserve fitted models and national totals; write separate crisis model files. Compare with age-specific population-only allocation. Keep changes country-specific in shared dispatch and report templates.

- [x] Inspect producer/consumer contracts and write application preservation test; observe missing Malawi dispatch failure.
- [x] Hash-verify backups of Malawi results, configuration, crisis input and final exports.
- [x] Implement Malawi wrapper, refresh dispatch and method notes; run allocation/application and relevant regression tests.
- [x] Regenerate spatial input and adjusted Admin-1/Admin-2 U5MR; enable doCrisisAdj only after successful application.
- [x] Refresh comparison dashboard, diagnostics, report figures, full country PDF and appendix, CC profile and combined current export.
- [x] Verify national deaths, all saved draws, unchanged non-2001 U5MR and NMR, source selection, current export scope and visual outputs. Record sensitivity and limitations in final manifest.

No survey, boundary, population-weight or model refitting is required. Existing unrelated working-tree changes must be preserved. Source: FAO/WFP 29 May 2002 Table 7; its projected June 2002-March 2003 food-aid need is a proxy for the national 2001 event, not measured crisis deaths. Zero weights do not demonstrate absence of mortality. No crisis uncertainty is added to model intervals.
