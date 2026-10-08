# Cameroon IGME refresh scope

Decision confirmed by the user on 2026-09-22: refresh the unstratified,
all-survey benchmarked model only. Do not require stratified results or repair
same-sampling-frame inputs for this refresh.

Verified against current files:

- `Info/Cameroon_general_info.json` selects `final_model.strata.model = unstrat`
  and `final_model.bench.model = bench`; Admin-1 and Admin-2 are enabled.
- `Data/Countries/Cameroon/Cameroon_cluster_dat.rda` contains survey years
  2004, 2011 and 2018. This is the all-survey input for the selected model.
- The saved same-frame data contain 2004 and 2011, while the JSON field
  `surveys_1frame` says 2011 and 2018. The user accepts the saved same-frame
  data and authorizes treating this discrepancy as non-blocking for the
  selected unstratified all-survey refresh.
- The selected-model refresh contract selects four results: Admin-1 and
  Admin-2, each for NMR and U5MR, all from the `allsurveys` family. All four
  unbenchmarked result files were present at this check. Presence alone is
  not a complete input or output validation.

Leave the same-frame data and JSON survey field unchanged. Do not suppress
other configuration failures, missing selected-model inputs, backup checks,
statistical validation, or visual review. The existing general configuration
test may still flag the same-frame discrepancy; retain and classify that
finding rather than reporting the entire test as passed.

This decision does not approve a stratified run or future data regeneration
with inconsistent frame metadata. Those workflows must reconcile the frame
definition first. Production scheduling remains with the benchmarking batch;
this note does not launch or restart it.
