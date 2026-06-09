# Dataset and Generated Data Policy

## Categories

- `data/test/`: small curated smoke-test inputs kept in the repository.
- `data/benchmark/`: benchmark fixtures that are small enough to review and keep.
- `data/small/`, `data/medium/`, `data/big/`: generated or large datasets. These are ignored by default unless explicitly curated.
- `tests/fixtures/results/`: small result CSV fixtures for plotting and summary validation.
- `results/`, `plots/`, temporary validation outputs: generated artifacts, ignored by default.

## Retention policy

Keep only compact fixtures needed for repeatable local validation. Large generated datasets and benchmark outputs should be regenerated, archived outside git, or attached to releases when intentionally preserved.

## Regeneration examples

```bash
python utils/kube-gen.py -o data/small -c 10 -i 5
python utils/kube-gen.py -o data/medium -c 100 -i 25
python utils/kube-gen.py -o data/big -c 400 -i 50
```

For simulator-specific formats, add the relevant flags such as `--kubemark`, `--simkube`, or `--open_sim` and record the exact command in the checkpoint log.

## Sensitive data

Do not store secrets, kubeconfigs, private keys, certificates, or real `.env` files in generated dataset directories.
