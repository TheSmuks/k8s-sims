# Data Model: Benchmark Reliability Stabilization

## Benchmark Result File

Represents one simulator's measured benchmark output.

**Fields**:
- `simulator_name`: Derived from the result file name or user-provided label.
- `node_count`: Number of nodes in the benchmark scenario.
- `pod_count`: Number of pods in the benchmark scenario.
- `timeout_reached`: Whether the run stopped because a duration or stalled-progress limit was reached.
- `mem_exceeded`: Whether the run stopped because the memory threshold was exceeded.
- `run_time`: Total recorded run duration.
- `total_cpu_seconds`: Total CPU time consumed by watched resources.
- `user_cpu_seconds`: User CPU time consumed by watched resources.
- `system_cpu_seconds`: System CPU time consumed by watched resources.
- `memory_peak_gb`: Peak memory usage recorded for watched resources.
- `unscheduled_pods`: Pods that remained unscheduled at the end of the run.
- `source_path`: Location of the result file.

**Validation rules**:
- Required columns must be present before plotting or summarization.
- Numeric fields must parse using the emitted result numeric format.
- Missing optional columns may use documented defaults only when doing so cannot mislead users.
- `pod_count` of zero must not cause division failures.
- Unknown `simulator_name` values must be accepted with a default presentation.

**Relationships**:
- Belongs to one Simulator Mode.
- Is created by one simulator run.
- Can be consumed by plotting and summary workflows.

## Simulator Mode

Represents a benchmark backend that can be active, experimental, unavailable, or legacy.

**Fields**:
- `name`: User-facing mode name.
- `status`: Active, experimental, unavailable, or legacy.
- `module_path`: Adapter location when implemented.
- `data_path_rule`: Expected dataset subdirectory or mapping rule.
- `setup_requirements`: Required local or container capabilities.
- `runtime_dependencies`: Required external tools, images, manifests, or repositories.
- `cleanup_expectations`: Resources that should be removed after run completion or failure.
- `verification_level`: Supported verification method in the current environment.

**Validation rules**:
- Every active mode must have a module path and data path rule.
- Any mode accepted by user-facing commands must appear in the authoritative inventory.
- Runtime dependencies must be categorized by reproducibility status.
- Cleanup expectations must be stated for resources the mode creates.

**Relationships**:
- Consumes Experiment Datasets.
- Produces Benchmark Result Files.
- May require Safety Notices.

## Experiment Dataset

Represents generated or curated benchmark input data.

**Fields**:
- `dataset_name`: Test, benchmark, small, medium, big, or future named set.
- `simulator_mode`: Associated simulator mode or shared input type.
- `node_count`: Scenario size represented by a file group.
- `file_group`: Node, pod, trace, cluster, or simulator-specific config files.
- `generation_source`: Script, fixture, imported artifact, or manual source.
- `source_control_status`: Kept in repository, generated on demand, external artifact, or ignored.
- `regeneration_command`: User-facing command or documented process to recreate the dataset.

**Validation rules**:
- Kept datasets must have a reason for being versioned.
- Large or generated datasets must have a documented regeneration or storage policy.
- Test fixtures must be small enough for local validation.

**Relationships**:
- Is consumed by Simulator Modes.
- May be produced by the dataset generator.

## Run Checkpoint

Represents one independently reviewable improvement group.

**Fields**:
- `checkpoint_name`: Concise label for the improvement group.
- `scope`: Files/workflows covered by the checkpoint.
- `requirements_covered`: Feature requirements addressed.
- `verification_commands`: Commands or manual checks performed.
- `verification_result`: Pass, fail, skipped, or blocked.
- `blocker`: Reason validation could not be completed, if any.
- `commit_reference`: Commit created after the checkpoint, when available.

**Validation rules**:
- Each checkpoint must cover a coherent set of related changes.
- Each checkpoint must include at least one verification result or a documented blocker.
- Failed verification must be resolved before the checkpoint is considered complete.

**Relationships**:
- Covers one or more requirements.
- Produces one commit or recorded review point.

## Safety Notice

Represents user-facing guidance for risky execution behavior.

**Fields**:
- `risk_area`: Privileged container, host cgroup access, runtime downloads, local environment files, or generated data volume.
- `affected_workflow`: Command or workflow where the risk applies.
- `impact`: What could happen if the user runs it on an unsuitable host.
- `recommended_environment`: Isolation or prerequisite guidance.
- `mitigation`: Practical action to reduce risk.

**Validation rules**:
- Privileged execution paths must have a notice before users are asked to run them.
- Notices must be discoverable from normal project guidance.
- Notices must distinguish required risk from avoidable risk.

**Relationships**:
- Applies to Simulator Modes and containerized workflows.

## Result Preservation Policy

Represents how existing output files are handled before a new run writes results.

**Fields**:
- `policy_name`: Preserve, overwrite, reject, timestamped output, or explicit backup.
- `default_behavior`: Behavior when the user does not choose a policy.
- `user_visible_message`: Message shown when existing results are detected.
- `plotting_interaction`: Whether preserved files should be included or excluded from plotting by default.

**Validation rules**:
- Existing outputs must not be silently overwritten.
- Backup or preservation behavior must be visible to the user.
- Preserved files must not be misclassified as additional simulator results unless intentionally selected.

**Relationships**:
- Governs Benchmark Result Files.
- Is validated by Run Checkpoints and quickstart scenarios.
