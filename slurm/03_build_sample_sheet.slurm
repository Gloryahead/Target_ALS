#!/bin/bash
# --------------------------------------------------------------
### Request resources
# --------------------------------------------------------------
#SBATCH --job-name=target_als_build_sample_sheet
#SBATCH --output=/xdisk/haining/maarowosegbe/target_als/logs/slurm/%x-%j.out
#SBATCH --error=/xdisk/haining/maarowosegbe/target_als/logs/slurm/%x-%j.err
#SBATCH --account=haining
#SBATCH --partition=standard
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4gb
#SBATCH --time=00:30:00

# Build config/samples.private.tsv from the downloaded folders. The job log contains COUNTS ONLY
# (safe to share); the sheet itself is private and git-ignored. Run before the pipeline; check the
# per-set counts against the 280-file inventory, and adjust sample_sheet.subject_regex if needed.
set -eo pipefail
export MAMBA_ROOT_PREFIX=/groups/haining/maarowosegbe/micromamba
MC=/opt/ohpc/pub/apps/micromamba/2.0.2-2/bin/micromamba
cd /home/u11/maarowosegbe/Target_ALS
"${MC}" run -n target_als_core python scripts/build_sample_sheet.py \
  --config config/config.yaml --out config/samples.private.tsv
