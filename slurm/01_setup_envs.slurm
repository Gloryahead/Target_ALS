#!/bin/bash
# --------------------------------------------------------------
### Request resources
# --------------------------------------------------------------
#SBATCH --job-name=target_als_setup_envs
#SBATCH --output=/xdisk/haining/maarowosegbe/target_als/logs/slurm/%x-%j.out
#SBATCH --error=/xdisk/haining/maarowosegbe/target_als/logs/slurm/%x-%j.err
#SBATCH --account=haining
#SBATCH --partition=standard
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --mem-per-cpu=4gb
#SBATCH --time=02:00:00

# Create the four micromamba environments (run once). The logs directory must exist before sbatch:
#   mkdir -p /xdisk/haining/maarowosegbe/target_als/logs/slurm
set -eo pipefail
export MAMBA_ROOT_PREFIX=/groups/haining/maarowosegbe/micromamba
MC=/opt/ohpc/pub/apps/micromamba/2.0.2-2/bin/micromamba
cd /home/u11/maarowosegbe/Target_ALS
for y in 00_snakemake 01_core 02_annotation 03_r; do
  echo "== ${y}"
  "${MC}" env create -f environments/${y}.yml --yes
done
echo "done: $(date)"
