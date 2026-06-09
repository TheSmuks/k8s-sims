# CLI Contracts: Benchmark Reliability Stabilization

This project exposes script and utility commands rather than a web API. These contracts describe expected user-facing behavior for planning and validation.

## Contract: Plot benchmark results

**Command family**: result plotting utility

**Inputs**:
- Required data directory containing result files.
- Optional output directory for plot artifacts.
- Options selecting line charts, bar summaries, or both.

**Preconditions**:
- Data directory exists and is readable.
- At least one readable result file is present for successful output generation.
- Result files use the project result-file schema documented in `data-model.md`.

**Successful behavior**:
- Generates requested plot artifacts in the output directory.
- Includes known simulator names with configured presentation.
- Includes unknown simulator names with default presentation.
- Handles constant-value metrics without undefined, infinite, or missing comparison values.
- Reports saved artifact paths.

**Failure behavior**:
- Missing data directory produces a clear error identifying the path.
- Empty directory produces a clear message that no result files were found.
- Malformed files are skipped or rejected with a message that identifies the file and problem.
- The command does not fail on startup due to syntax or import errors when required dependencies are installed.

**Result file format**:
- Files are pipe-delimited CSV (`|`) with a header row.
- Numeric values may use comma decimals, matching the runner output format used by the project fixtures.
- Required fields for plotting are `node_count`, `pod_count`, `timeout_reached`, `mem_exceeded`, `run_time`, `total_cpu_seconds`, `user_cpu_seconds`, `system_cpu_seconds`, `memory_peak_gb`, and `unscheduled_pods`.
- Preserved backup files named `*.preserved-*.csv` are ignored by default so they do not appear as extra simulator series.

**Validation examples**:
- Valid fixtures produce line and bar outputs.
- Missing directory returns a clear error and no traceback for expected input errors.
- Custom result file name is plotted using default style.
- Constant metrics produce finite normalized values.

## Contract: Summarize benchmark results

**Command family**: result summary utility

**Inputs**:
- Required data directory containing result files.
- Optional output directory for summary artifacts.

**Preconditions**:
- Data directory exists and is readable.
- Result files contain required numeric metrics.

**Successful behavior**:
- Creates a summary artifact with min, average, and max values for supported metrics.
- Excludes or reports invalid files without producing misleading aggregate values.
- Creates the output directory when missing.

**Failure behavior**:
- Missing or unreadable input directory produces a clear error.
- No valid result files produces a clear error and does not create a misleading empty summary.

## Contract: Generate benchmark datasets

**Command family**: dataset generator utility

**Inputs**:
- Required output directory.
- Node count and optional increment.
- Optional simulator-specific format flags.
- Optional tracing or experiment-run flags.
- Optional paths to base nodes, pods, hollow-node template, or new-node template.

**Preconditions**:
- Base input files exist and are readable.
- Output directory can be created or written.

**Successful behavior**:
- Generates node and pod files for requested sizes.
- Applies simulator-specific formatting when requested.
- Handles valid paths containing spaces.
- When invoking follow-on workflows, preserves argument boundaries and does not execute unintended shell content.

**Failure behavior**:
- Missing input files produce clear errors.
- Invalid arguments stop before partial follow-on execution where possible.

## Contract: Run a single simulator experiment

**Command family**: per-simulator runner

**Inputs**:
- Experiment file directory.
- Simulator mode.
- Optional run count.
- Optional starting node count.
- Optional output file.
- Optional memory threshold.
- Optional maximum simulation time.

**Preconditions**:
- Simulator mode is present in the authoritative simulator inventory.
- Required experiment files for the selected mode exist.
- Required external tools and privileges for the selected mode are available, or the command reports the missing prerequisite.

**Successful behavior**:
- Loads the correct simulator module independent of current working directory.
- Creates the default output directory before writing if no output file is provided.
- Writes one result row per completed run attempt with timeout and memory-limit status.
- Stops stalled or over-duration runs according to configured limits.
- Stops and records runs that exceed the memory threshold.
- Attempts cleanup after completion, interruption, or failure.

**Failure behavior**:
- Unsupported mode produces a clear error.
- Missing experiment path produces a clear error.
- Setup failure prevents misleading result rows and records/logs the setup reason.
- Cleanup failure is visible to the user.

## Contract: Run all configured simulators

**Command family**: multi-simulator coordinator

**Inputs**:
- Experiment root directory.
- Run count.
- Optional starting node count.
- Output directory.
- Memory threshold.
- Maximum simulation time.
- Optional plot-after-run selection.

**Preconditions**:
- Active simulator list is readable.
- Each configured simulator has an inventory entry and module behavior.
- Output directory exists or can be created according to the result policy.

**Successful behavior**:
- Runs configured simulators in order.
- Uses the correct data path rule for each simulator.
- Applies result preservation policy before writing each simulator result.
- Cleans simulator resources after each simulator or failed run.
- If plotting is requested, invokes plotting only after result generation is complete and reports plotting failures clearly.

**Failure behavior**:
- A simulator failure stops or skips according to documented policy.
- Remaining resources are cleaned up best-effort.
- The user can identify which simulator failed and why.

## Contract: Result preservation

**Applies to**: single-simulator and multi-simulator runs

**Inputs**:
- Target output file or output directory.
- Existing result file state.
- Optional explicit overwrite or preservation selection if implemented.

**Expected behavior**:
- Existing output files are never silently overwritten.
- If files are preserved or renamed, the user sees the new location or name.
- Preserved backup files are excluded from plotting by default unless intentionally selected or clearly named as result inputs.
- The policy is documented and consistent across runner entry points.
