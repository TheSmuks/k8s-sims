# Data Model: End-to-End Framework Validation

## Validation Run

Represents one bounded execution of the end-to-end framework validation effort.

**Fields**:
- `run_id`: Stable identifier for the run, preferably date/time plus branch or revision.
- `feature_directory`: Project-relative path to the feature artifacts.
- `started_at`: Timestamp when baseline verification begins.
- `completed_at`: Timestamp when final validation report is complete.
- `host_summary`: OS, shell, and relevant environment facts observed during the run.
- `baseline`: Reference to the Remote Baseline entity.
- `tool_evidence`: Collection of Tool Evidence entries.
- `simulator_outcomes`: Collection of Simulator Mode outcomes.
- `workload_artifacts`: Collection of Workload Artifact entries.
- `failure_records`: Collection of Failure Record entries.
- `fix_records`: Collection of Fix Record entries.
- `final_status`: One of `in-progress`, `passed`, `passed-with-fixed-failures`, `blocked-external`, or `failed-unresolved`.

**Validation rules**:
- Must start from a clean remote-derived baseline.
- Must include at least one evidence entry for repository status and each tool used in claims.
- Cannot be final while project-scope failures remain unresolved.

**State transitions**:
- `created` → `baseline-verified` after remote, branch, revision, and clean status are recorded.
- `baseline-verified` → `validating` after tool and documentation evidence collection begins.
- `validating` → `fixing` when a project-scope failure is found.
- `fixing` → `validating` after the relevant fix is re-verified.
- `validating` → `complete` after all outcomes are classified and report evidence is complete.

## Remote Baseline

Represents the checked repository state used as the source of truth.

**Fields**:
- `remote_url`: Fetch URL used for the clean checkout.
- `default_branch`: Remote default or selected starting branch.
- `baseline_revision`: Commit hash used before feature changes.
- `working_tree_status`: Clean status evidence.
- `clone_path`: Local path used for isolated validation.
- `verification_commands`: Commands used to prove the baseline.

**Validation rules**:
- Working tree must be clean before validation commands run.
- If the primary working tree is dirty, the baseline must be isolated in a separate path.

## Tool Evidence

Represents a checked fact about a tool, project document, or external dependency.

**Fields**:
- `name`: Tool or document name.
- `source_type`: One of `command-output`, `repository-document`, `external-documentation`, or `observed-behavior`.
- `source_reference`: Command, file path, URL, or excerpt location.
- `observed_value`: Version, behavior, requirement, or claim.
- `checked_at`: Timestamp or run phase when checked.
- `impact`: What validation decision depends on this evidence.

**Validation rules**:
- Every factual claim in the final report must link to one or more Tool Evidence entries.
- Version claims must come from observed command output when the tool is installed.

## Simulator Mode

Represents one active framework simulator workflow.

**Fields**:
- `mode`: Mode name such as `kwok`, `kube-sched`, `simkube`, `kubemark`, or `opensim`.
- `module_path`: Project-relative module path.
- `data_path_rule`: Dataset or artifact shape consumed by the mode.
- `documented_prerequisites`: Required tools, privileges, host capabilities, and setup steps.
- `entry_point`: Framework command used for validation.
- `cleanup_expectation`: Documented cleanup behavior.
- `fallback_checks`: Non-privileged checks used when full runtime is unavailable.
- `outcome`: One of `pass`, `fixed`, `skipped-documented-constraint`, or `blocked-external`.
- `evidence_refs`: Links to command outputs, files, and failure or fix records.

**Validation rules**:
- Every active simulator mode must have exactly one final outcome.
- Modes blocked by host or external constraints must still have fallback checks where available.

## Workload Artifact

Represents generated or selected input data used to exercise the framework.

**Fields**:
- `artifact_path`: Project-relative or temporary path.
- `artifact_type`: One of `nodes-manifest`, `pods-manifest`, `simkube-trace`, `opensim-config`, `plot-input`, or `result-output`.
- `created_by`: Command or fixture source.
- `target_modes`: Simulator modes that consume the artifact.
- `validation_status`: One of `present`, `structurally-valid`, `invalid`, or `missing`.
- `evidence_refs`: Commands or checks proving status.

**Validation rules**:
- Artifacts used in simulator execution must be checked for presence before execution.
- Trace artifacts must be structurally checked before SimKube use.

## Failure Record

Represents an observed failure, mismatch, timeout, or unexpected behavior.

**Fields**:
- `failure_id`: Stable identifier.
- `phase`: Baseline, documentation, generation, unit-test, bash-test, simulator-run, cleanup, or report.
- `action`: Command or check that failed.
- `observed_output`: Relevant output excerpt or report path.
- `expected_behavior`: Behavior required by spec, constitution, docs, or contract.
- `root_cause`: Diagnosed cause.
- `scope`: One of `project-defect`, `external-dependency`, `platform-constraint`, `documentation-mismatch`, or `test-environment`.
- `resolution`: Fix applied, blocker documented, or fallback chosen.
- `post_resolution_status`: One of `pass`, `fixed`, `blocked`, or `superseded`.
- `verification_refs`: Post-resolution commands or evidence.

**Validation rules**:
- Every failed action must have a Failure Record.
- Project defects cannot remain in `blocked` or `unresolved` status.
- Documentation mismatches require documentation updates or an explicit correction record.

## Fix Record

Represents a project change made to resolve one or more failures.

**Fields**:
- `fix_id`: Stable identifier.
- `related_failures`: Failure IDs addressed by the fix.
- `changed_paths`: Repository paths changed.
- `change_summary`: User-facing description of the fix.
- `test_first_evidence`: Required for shell changes.
- `verification_commands`: Commands re-run after the fix.
- `documentation_updates`: Paths updated if behavior changed.

**Validation rules**:
- Shell fixes must reference failing or updated bats coverage before the implementation fix.
- Every fix must have post-fix verification evidence.

## Validation Report

Represents the final auditable report for the feature.

**Fields**:
- `baseline_summary`: Remote Baseline summary.
- `environment_summary`: Tool Evidence summary.
- `coverage_matrix`: Validation layer and simulator outcome table.
- `failure_log`: All Failure Records.
- `fix_log`: All Fix Records.
- `blockers`: External or platform blockers with fallback evidence.
- `reproduction_steps`: Commands needed to reproduce the final result from a clean checkout.
- `final_verdict`: Overall status and remaining risk.

**Validation rules**:
- Must include every active simulator mode.
- Must distinguish original failure evidence from post-fix verification evidence.
- Must be reproducible without hidden local state.
