1|1|1|# Tasks: Overhaul SimKube Trace Generation
2|2|2|
3|3|3|**Input**: Design documents from `/specs/003-trace-gen-overhaul/`
4|4|4|
5|5|5|**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md
6|6|6|
7|7|7|**Tests**: Included -- spec explicitly requires unit test coverage for bin-packing (SC-003) and trace validation (SC-002).
8|8|8|
9|9|9|**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.
10|10|10|
11|11|11|## Format: `[ID] [P?] [Story] Description`
12|12|12|
13|13|13|- **[P]**: Can run in parallel (different files, no dependencies)
14|14|14|- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
15|15|15|- Include exact file paths in descriptions
16|16|16|
17|17|17|## Path Conventions
18|18|18|
19|19|19|- **Project type**: CLI toolkit (Shell + Python hybrid)
20|20|20|- **Source**: `utils/` (Python modules), `overlays/` (kustomize), `modules/` (shell)
21|21|21|- **Tests**: `tests/` (Python pytest), `tests/bash/` (existing bats suite)
22|22|22|
23|23|23|---
24|24|24|
25|25|25|## Phase 1: Setup
26|26|26|
27|27|27|**Purpose**: Add new dependency and create test fixture data.
28|28|28|
29|29|29|- [X] T001 Add `msgpack` to `requirements.txt` at project root
30|30|30|- [X] T002 [P] Create test fixture: `tests/fixtures/nodes-small.yaml` with 5 heterogeneous nodes (varying CPU/memory, some with labels for affinity tests)
31|31|31|- [X] T003 [P] Create test fixture: `tests/fixtures/pods-small.yaml` with 10 pods (varying requests, some with nodeAffinity, some with no resource requests)
32|32|32|
33|33|33|---
34|34|34|
35|35|35|## Phase 2: Foundational (Blocking Prerequisites)
36|36|36|
37|37|37|**Purpose**: Core data structures and parsing that ALL user stories depend on.
38|38|38|
39|39|39|**CRITICAL**: No user story work can begin until this phase is complete.
40|40|40|
41|41|41|- [X] T004 Create `utils/binpack.py` with dataclasses: `NodeSpec`, `PodSpec`, `NodeAffinity`, `MatchExpression`, `PlacementResult`, `Rejection` per data-model.md
42|42|42|- [X] T005 Implement `parse_node(raw_manifest: dict) -> NodeSpec` in `utils/binpack.py` -- extracts name, cpu_capacity, memory_capacity, labels from raw Kubernetes node YAML
43|43|43|- [X] T006 Implement `parse_pod(raw_manifest: dict) -> PodSpec` in `utils/binpack.py` -- extracts name, namespace, cpu_request (default 0), memory_request (default 0), tolerations, node_affinity, node_selector from raw Kubernetes pod YAML
44|44|44|- [X] T007 Implement resource parsing helpers `parse_cpu(cpu_str: str) -> int` and `parse_memory(mem_str: str) -> int` in `utils/binpack.py` (move from kube-gen.py, handle `m` suffix and `Mi` suffix)
45|45|45|- [X] T008 Implement `check_affinity(node: NodeSpec, pod: PodSpec) -> bool` in `utils/binpack.py` -- checks `requiredDuringSchedulingIgnoredDuringExecution` nodeSelectorTerms + nodeSelector against node labels
46|46|46|- [X] T009 Implement `check_resources(remaining_cpu: int, remaining_mem: int, pod: PodSpec) -> bool` in `utils/binpack.py`
47|47|47|- [X] T010 Implement `place(nodes: list[NodeSpec], pods: list[PodSpec]) -> PlacementResult` in `utils/binpack.py` -- first-fit greedy: iterate pods, for each pod iterate nodes, apply filter chain (affinity -> resources), assign or reject with reason
48|48|48|
49|49|49|**Checkpoint**: Foundation ready -- `binpack.py` is importable and functional. User story implementation can now begin in parallel.
50|50|50|
51|51|51|---
52|52|52|
53|53|53|## Phase 3: User Story 1 - Direct .sktrace Generation (Priority: P1) -- MVP
54|54|54|
55|55|55|**Goal**: Generate valid SimKube v2 `.sktrace` files in Python without any cluster tooling.
56|56|56|
57|57|57|**Independent Test**: Run `python -m pytest tests/test_sktrace.py -v` then verify a generated trace with `msgpack.unpackb`.
58|58|58|
59|59|59|### Tests for User Story 1
60|60|60|
61|61|61|- [X] T011 [P] [US1] Create `tests/test_sktrace.py` -- test trace has correct top-level keys (version, config, events, index, pod_lifecycles)
62|62|62|- [X] T012 [P] [US1] Add test: version field is 2 in `tests/test_sktrace.py`
63|63|63|- [X] T013 [P] [US1] Add test: config has `trackedObjects` (camelCase) with `v1.Pod` in `tests/test_sktrace.py`
64|64|64|- [X] T014 [P] [US1] Add test: events[0] has ts, applied_objs, deleted_objs (snake_case) in `tests/test_sktrace.py`
65|65|65|- [X] T015 [P] [US1] Add test: pod_lifecycles is empty dict in `tests/test_sktrace.py`
66|66|66|- [X] T016 [P] [US1] Add test: msgpack roundtrip (pack then unpack produces same structure) in `tests/test_sktrace.py`
67|67|67|- [X] T017 [P] [US1] Add test: index has correct GVK key format `"v1.Pod"` and `namespace/name` entries in `tests/test_sktrace.py`
68|68|68|
69|69|69|### Implementation for User Story 1
70|70|70|
71|71|71|- [X] T018 [US1] Create `utils/sktrace.py` with trace schema constants: `TRACE_VERSION = 2`, field names (`trackedObjects`, `applied_objs`, `deleted_objs`, `ts`, `pod_lifecycles`)
72|72|72|- [X] T019 [US1] Implement `compute_spec_hash(spec: dict) -> int` in `utils/sktrace.py` -- SHA-256 of JSON-serialized spec, take first 8 bytes as u64
73|73|73|- [X] T020 [US1] Implement `build_trace(placement: PlacementResult, config: dict, timestamp: int) -> dict` in `utils/sktrace.py` -- builds full ExportedTrace dict: version=2, config with trackedObjects, events=[single snapshot event], index with GVK->name->hash, pod_lifecycles={}
74|74|74|- [X] T021 [US1] Implement `write_sktrace(trace: dict, path: str) -> None` in `utils/sktrace.py` -- `msgpack.packb(trace, use_bin_type=True)` and write binary to file
75|75|75|- [X] T022 [US1] Implement `validate_sktrace(path: str) -> bool` in `utils/sktrace.py` -- try `skctl validate` subprocess; if skctl not found, log warning and return True (graceful degradation per FR-011)
76|76|76|
77|77|77|**Checkpoint**: User Story 1 complete -- `.sktrace` files can be generated from PlacementResult objects. Run `python -m pytest tests/test_sktrace.py -v` to verify.
78|78|78|
79|79|79|---
80|80|80|
81|81|81|## Phase 4: User Story 2 - Modular Bin-Packing (Priority: P2)
82|82|82|
83|83|83|**Goal**: Extract bin-packing into a standalone, testable module with affinity and resource constraints.
84|84|84|
85|85|85|**Independent Test**: Run `python -m pytest tests/test_binpack.py -v` with deterministic fixture assertions.
86|86|86|
87|87|87|### Tests for User Story 2
88|88|88|
89|89|89|- [X] T023 [US2] Create `tests/test_binpack.py` -- test first-fit: 5 nodes (4 CPU, 8Gi) + 20 pods (1 CPU, 2Gi) = 20 placed, 0 rejected
90|90|90|- [X] T024 [P] [US2] Add test: affinity constraint -- pod targets label on half the nodes, excess rejected with reason "affinity_constraint" in `tests/test_binpack.py`
91|91|91|- [X] T025 [P] [US2] Add test: insufficient resources -- more demand than capacity, rejected with reason "insufficient_resources" in `tests/test_binpack.py`
92|92|92|- [X] T026 [P] [US2] Add test: zero-cost pods (no resource requests) always placed in `tests/test_binpack.py`
93|93|93|- [X] T027 [P] [US2] Add test: heterogeneous node capacities handled correctly in `tests/test_binpack.py`
94|94|94|- [X] T028 [P] [US2] Add test: nodeSelector + nodeAffinity both must be satisfied in `tests/test_binpack.py`
95|95|95|
96|96|96|### Implementation for User Story 2
97|97|97|
98|98|98|Implementation is already complete from Phase 2 foundational tasks (T004-T010). This phase validates correctness via tests.
99|99|99|
100|100|100|**Checkpoint**: User Story 2 complete -- bin-packing is extracted, stateless, and fully tested. Run `python -m pytest tests/test_binpack.py -v`.
101|101|101|
102|102|102|---
103|103|103|
104|104|104|## Phase 5: User Story 3 - Kustomize Overlays (Priority: P3)
105|105|105|
106|106|106|**Goal**: Replace Python patch callbacks with declarative kustomize overlay directories.
107|107|107|
108|108|108|**Independent Test**: Run `kubectl kustomize overlays/simkube/` and verify output is semantically equivalent to current `patch_kwok_node`/`patch_kwok_pod` output.
109|109|109|
110|110|110|### Implementation for User Story 3
111|111|111|
- [X] T029 [P] [US3] Create `overlays/simkube/kustomization.yaml` with inline patches using `target.kind` selectors for Node and Pod
- [X] T030 [P] [US3] Simkube Node inline patch: `kwok.x-k8s.io/node: fake` annotation + `openb-only=true:NoSchedule` taint
- [X] T031 [P] [US3] Simkube Pod inline patch: toleration for `openb-only` key Equal true NoSchedule
- [X] T032 [P] [US3] Create `overlays/kubemark/kustomization.yaml` with inline patches matching current `patch_hollow_node` behavior (KWOK annotation, taint)
- [X] T033 [P] [US3] Kubemark Pod inline patch matching current `patch_hollow_pod` behavior (nodeAffinity for `kubemark-node`)
- [X] T034 [US3] Verify semantic equivalence: load both Python-patched and kustomize-patched output with `yaml.safe_load_all`, compare parsed dicts for nodes and pods
- [X] T035 [P] [US3] Create `overlays/opensim/kustomization.yaml` placeholder (minimal, no patches until OpenSim module is reworked)
119|119|119|
120|120|120|**Checkpoint**: User Story 3 complete -- kustomize overlays produce semantically equivalent output. Verify with `kubectl kustomize overlays/simkube/`.
121|121|121|
122|122|122|---
123|123|123|
124|124|124|## Phase 6: User Story 4 - Trace Validation Step (Priority: P4)
125|125|125|
126|126|126|**Goal**: Automatic validation of generated `.sktrace` files via `skctl validate`, with graceful skip when skctl is absent.
127|127|127|
128|128|128|**Independent Test**: Generate a trace, then run validation; generate a corrupted trace, verify error is caught.
129|129|129|
130|130|130|### Implementation for User Story 4
131|131|131|
132|132|132|- [X] T036 [US4] Implement validation integration in `utils/sktrace.py` -- `validate_sktrace` already created in T022; add `validate_traces_in_dir(dir: str) -> bool` that validates all `.sktrace` files in a directory
133|133|133|- [X] T037 [US4] Add validation call to `kube-gen.py` generation loop: after writing all trace files, call `validate_traces_in_dir(output_folder)`, log results, warn but don't fail if skctl absent
134|134|134|
135|135|135|**Checkpoint**: User Story 4 complete -- traces are validated after generation. Test by running generation with and without skctl on PATH.
136|136|136|
137|137|137|---
138|138|138|
139|139|139|## Phase 7: Integration -- Wire Everything into kube-gen.py
140|140|140|
141|141|141|**Purpose**: Refactor `kube-gen.py` to use the new modules, remove old code, produce both YAML and trace output.
142|142|142|
143|143|143|- [X] T038 Refactor `kube-gen.py`: remove all global mutable state (nodes, pods, total_node_resources, selected_nodes, selected_pods, loaded_nodes_qty, animation_msg, done, template_hollow_node, simon_template, new_node_path)
144|144|144|- [X] T039 Refactor `kube-gen.py`: remove `patch_kwok_node`, `patch_kwok_pod`, `patch_hollow_node`, `patch_hollow_pod` functions
145|145|145|- [X] T040 Refactor `kube-gen.py`: remove `run_simkube_tracer` function and the `--tracer`/`-t` subprocess path
146|146|146|- [X] T041 Add `apply_overlay(manifests_yaml: str, overlay_dir: str) -> str` to `utils/kube-gen.py` -- calls `kubectl kustomize` via subprocess with the overlay dir, returns patched YAML stdout; raises RuntimeError with clear message if kubectl not found
147|147|147|- [X] T042 Refactor `generate_n_nodes` in `utils/kube-gen.py` to use `binpack.parse_node`, `binpack.parse_pod`, `binpack.place()` returning `PlacementResult`, then apply kustomize overlay to node/pod manifests before writing YAML files
148|148|148|- [X] T043 Add trace generation to `kube-gen.py` generation loop: after each increment, call `sktrace.build_trace()` then `sktrace.write_sktrace()` to produce `trace-{N}.sktrace` alongside `nodes-{N}.yaml` and `pods-{N}.yaml`
149|149|149|- [X] T044 Update `--tracer`/`-t` flag in `utils/kube-gen.py` to generate `.sktrace` directly (no subprocess), make it default behavior when `--simkube` is selected
150|150|150|- [X] T045 Preserve CLI backward compatibility: same `-s`, `-k`, `-os`, `-t`, `-c`, `-i` flags, same output file naming convention
151|151|151|
152|152|152|---
153|153|153|
154|154|154|## Phase 8: Cleanup & Documentation
155|155|155|
156|156|156|**Purpose**: Remove dead code, update docs, validate end-to-end.
157|157|157|
158|158|158|- [X] T046 Delete `utils/simkube-tracer.sh`
159|159|159|- [X] T047 [P] Update `ARCHITECTURE.md`: remove simkube-tracer.sh references, add `utils/binpack.py`, `utils/sktrace.py`, `overlays/` documentation
160|160|160|- [X] T048 [P] Update `README.md`: update SimKube usage instructions to reflect new `--tracer` behavior (direct generation, no cluster needed)
161|161|161|- [X] T049 [P] Update `modules/simkube/module.sh`: replace tracer invocation with trace generation via `kube-gen.py --simkube -t`
162|162|162|- [X] T050 Update `utils/base/config.yml`: add comment documenting why only `v1.Pod` is tracked (static snapshot mode, no higher-level owners)
163|163|163|- [X] T051 Run full integration test: `python utils/kube-gen.py --simkube -c 100 -i 25 -o output/integration-test/` and verify all output files exist with correct structure
164|164|164|- [X] T052 Run performance benchmark: `time python utils/kube-gen.py --simkube -c 1200 -i 200 -o output/perf-test/` and verify <5s completion (SC-001)
165|165|165|- [X] T053 Run existing bats test suite to ensure no regressions: `bash tests/bash/run.sh`
166|166|166|
167|167|167|---
168|168|168|
169|169|169|## Dependencies & Execution Order
170|170|170|
171|171|171|### Phase Dependencies
172|172|172|
173|173|173|- **Setup (Phase 1)**: No dependencies -- start immediately
174|174|174|- **Foundational (Phase 2)**: Depends on T001 (msgpack dep) -- BLOCKS all user stories
175|175|175|- **US1 (Phase 3)**: Depends on Phase 2 -- trace generator needs binpack dataclasses
176|176|176|- **US2 (Phase 4)**: Depends on Phase 2 -- tests validate foundational binpack module
177|177|177|- **US3 (Phase 5)**: No dependency on Phase 2 -- kustomize overlays are standalone YAML files
178|178|178|- **US4 (Phase 6)**: Depends on Phase 3 (T022) -- validation uses sktrace module
179|179|179|- **Integration (Phase 7)**: Depends on Phase 3 + 4 + 5 -- wires all modules together
180|180|180|- **Cleanup (Phase 8)**: Depends on Phase 7 -- removes old code only after integration works
181|181|181|
182|182|182|### User Story Dependencies
183|183|183|
184|184|184|- **US1 (P1)**: Needs binpack dataclasses (Phase 2). No dependency on other stories.
185|185|185|- **US2 (P2)**: Needs binpack module (Phase 2). No dependency on other stories.
186|186|186|- **US3 (P3)**: Fully standalone. Can start immediately after Phase 1.
187|187|187|- **US4 (P4)**: Needs US1's `sktrace.py` (T022).
188|188|188|
189|189|189|### Within Each User Story
190|190|190|
191|191|191|- Tests written and FAILING before implementation (where applicable)
192|192|192|- Data structures before logic
193|193|193|- Core implementation before integration
194|194|194|- Story complete before moving to next priority
195|195|195|
196|196|196|### Parallel Opportunities
197|197|197|
198|198|198|- T002 + T003: test fixtures can be written in parallel
199|199|199|- T011-T017: all US1 test tasks can run in parallel
200|200|200|- T023-T028: all US2 test tasks can run in parallel
201|201|201|- T029-T033: all US3 overlay files can be created in parallel
202|202|202|- T047-T050: all documentation updates can run in parallel
203|203|203|
204|204|204|---
205|205|205|
206|206|206|## Parallel Example: User Story 1 + User Story 3 (max throughput)
207|207|207|
208|208|208|```text
209|209|209|# Stream A: Trace generator
210|210|210|Task T018: "Create utils/sktrace.py with trace schema constants"
211|211|211|Task T019: "Implement compute_spec_hash in utils/sktrace.py"
212|212|212|Task T020: "Implement build_trace in utils/sktrace.py"
213|213|213|Task T021: "Implement write_sktrace in utils/sktrace.py"
214|214|214|Task T022: "Implement validate_sktrace in utils/sktrace.py"
215|215|215|
# Stream B: Kustomize overlays (independent, different files)
Task T029: "Create overlays/simkube/kustomization.yaml with inline patches"
Task T030: "Simkube Node inline patch: KWOK annotation + taint"
Task T031: "Simkube Pod inline patch: toleration for openb-only"
Task T032: "Create overlays/kubemark/kustomization.yaml with inline patches"
Task T033: "Kubemark Pod inline patch: nodeAffinity for kubemark-node"
222|222|222|```
223|223|223|
224|224|224|---
225|225|225|
226|226|226|## Implementation Strategy
227|227|227|
228|228|228|### MVP First (User Stories 1 + 2 Only)
229|229|229|
230|230|230|1. Complete Phase 1: Setup (T001-T003)
231|231|231|2. Complete Phase 2: Foundational (T004-T010)
232|232|232|3. Complete Phase 3: US1 Direct .sktrace (T011-T022)
233|233|233|4. Complete Phase 4: US2 Bin-packing tests (T023-T028)
234|234|234|5. **STOP and VALIDATE**: `python -m pytest tests/ -v` -- all tests pass
235|235|235|6. Now you have a working trace generator with tested bin-packing
236|236|236|
237|237|237|### Full Delivery
238|238|238|
239|239|239|1. Setup + Foundational -> Foundation ready
240|240|240|2. Add US1 + US2 -> Test -> Working core (MVP!)
241|241|241|3. Add US3 -> Test -> Kustomize overlays replace Python patches
242|242|242|4. Add US4 -> Test -> Validation step integrated
243|243|243|5. Phase 7 Integration -> Wire into kube-gen.py
244|244|244|6. Phase 8 Cleanup -> Remove old tracer, update docs
245|245|245|7. Run quickstart.md validation scenarios
246|246|246|
247|247|247|---
248|248|248|
249|249|249|## Notes
250|250|250|
251|251|251|- [P] tasks = different files, no dependencies
252|252|252|- [Story] label maps task to specific user story for traceability
253|253|253|- Each user story should be independently completable and testable
254|254|254|- Commit after each task or logical group using conventional commits (e.g., `feat(utils):`, `test(utils):`, `refactor(utils):`)
255|255|255|- Stop at any checkpoint to validate story independently
256|256|256|- Taint/toleration filtering is NOT in binpack -- kustomize overlays handle it uniformly
257|257|257|- `pod_lifecycles` is always empty `{}` for static snapshots (no tuple-key msgpack issues)
258|258|258|