#!/bin/bash
# --------------------------------------------------------------
### Request resources
# --------------------------------------------------------------
#SBATCH --job-name=target_als_full_build_sample_sheet
#SBATCH --output=/xdisk/haining/maarowosegbe/target_als_full/logs/slurm/%x-%j.out
#SBATCH --error=/xdisk/haining/maarowosegbe/target_als_full/logs/slurm/%x-%j.err
#SBATCH --account=haining
#SBATCH --partition=standard
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4gb
#SBATCH --time=00:30:00

# Build config/samples_full.private.tsv from the downloaded folders of the FULL-TABLE run. The job log
# contains COUNTS ONLY (safe to share). Expected: nygc_sr 71, psomagen_sr 137, psomagen_lr 81 subjects.
set -eo pipefail
export MAMBA_ROOT_PREFIX=/groups/haining/maarowosegbe/micromamba
MC=/opt/ohpc/pub/apps/micromamba/2.0.2-2/bin/micromamba
cd /home/u11/maarowosegbe/Target_ALS
"${MC}" run -n snakemake_env python scripts/build_sample_sheet.py \
  --config config/config_full.yaml --out config/samples_full.private.tsv
