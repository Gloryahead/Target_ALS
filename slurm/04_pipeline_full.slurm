#!/bin/bash
# --------------------------------------------------------------
### Request resources
# --------------------------------------------------------------
#SBATCH --job-name=target_als_full_pipeline
#SBATCH --output=/xdisk/haining/maarowosegbe/target_als_full/logs/slurm/%x-%j.out
#SBATCH --error=/xdisk/haining/maarowosegbe/target_als_full/logs/slurm/%x-%j.err
#SBATCH --account=haining
#SBATCH --partition=standard
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --mem-per-cpu=4gb
#SBATCH --time=240:00:00

### The SLURM job itself only runs the Snakemake controller (low CPU/RAM). Snakemake submits each rule
### as its own child SLURM job with the resources declared in workflow/rules/*.smk.

set -eo pipefail
# A failed dry run must stop the script instead of falling through into the full run.

echo "========== Pipeline started at: $(date) =========="
echo "  Node    : $(hostname)"
echo "  Job ID  : ${SLURM_JOB_ID}"

SCRIPT_BASE=/home/u11/maarowosegbe/Target_ALS
DATA_BASE=/xdisk/haining/maarowosegbe/target_als_full
export MAMBA_ROOT_PREFIX=/groups/haining/maarowosegbe/micromamba
MC=/opt/ohpc/pub/apps/micromamba/2.0.2-2/bin/micromamba

cd "${SCRIPT_BASE}"

echo ""
echo "--- Snakemake dry run (DAG check) ---"
"${MC}" run -n snakemake_env \
  snakemake \
    --snakefile "${SCRIPT_BASE}/workflow/Snakefile" \
    --configfile "${SCRIPT_BASE}/config/config_full.yaml" \
    --profile "${SCRIPT_BASE}/workflow/profiles/slurm" \
    --dry-run --quiet

echo ""
echo "--- Full pipeline run ---"
"${MC}" run -n snakemake_env \
  snakemake \
    --snakefile "${SCRIPT_BASE}/workflow/Snakefile" \
    --configfile "${SCRIPT_BASE}/config/config_full.yaml" \
    --profile "${SCRIPT_BASE}/workflow/profiles/slurm" \
    --rerun-incomplete --keep-going --latency-wait 60 --jobs 100 --printshellcmds \
  2>&1 | tee "${DATA_BASE}/logs/slurm/snakemake_${SLURM_JOB_ID}.log"

echo "========== Pipeline finished at: $(date) =========="
