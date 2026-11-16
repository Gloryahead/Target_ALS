#!/bin/bash
# Dry-run (snakemake -n) on the invented placeholder sample sheet. Run from the repo root inside snakemake_env.
set -euo pipefail
bash tests/make_fake_inputs.sh
snakemake -n --snakefile workflow/Snakefile --configfile config/config.yaml tests/config.fake.yaml "$@"
