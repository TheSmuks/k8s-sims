# Security and Runtime Safety

This benchmark toolkit can run privileged container and simulator workflows. Treat full simulator execution as a local infrastructure operation, not as a harmless plotting command.

## Privileged Docker and Docker-in-Docker

The containerized workflow uses Docker-in-Docker and expects access to Docker, kind, KWOK, and simulator images. Privileged execution can affect host networking, images, containers, and cgroups. Run full benchmarks only on an isolated development host, disposable VM, or dedicated benchmark machine.

## Host cgroup access

OpenSimulator and resource tracking inspect or create cgroup paths under `/sys/fs/cgroup`. On non-Linux hosts, containers, or locked-down machines this may fail. These failures should be treated as environment blockers, not benchmark results.

## Runtime downloads

Some modules clone repositories or pull manifests/images at runtime. Network availability and upstream changes can affect reproducibility. See `SIM_MODULES.md` for pinned and intentionally variable dependencies.

## Local environment files

Do not commit real `.env` files or kubeconfig secrets. Use documented environment variables or non-secret examples only. `.env*`, kubeconfigs, keys, certificates, and secret manifests are ignored by default.

## Recommended isolation

- Prefer a disposable VM or dedicated Linux benchmark host.
- Avoid running privileged benchmarks on a personal workstation with important containers.
- Review `docker compose` and module scripts before granting host-level privileges.
- Clean up kind, KWOK, Docker, and cgroup resources after interrupted runs.

## Non-privileged limitations

Without Docker, privileged cgroups, and Kubernetes tooling, maintainers can still run syntax checks, Python compilation, fixture plotting, dataset generation, and documentation checks through `utils/validate-checkpoint.sh`.
