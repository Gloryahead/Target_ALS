#!/bin/bash
# --------------------------------------------------------------
### Request resources
# --------------------------------------------------------------
#SBATCH --job-name=target_als_report
#SBATCH --output=/xdisk/haining/maarowosegbe/target_als/logs/slurm/%x-%j.out
#SBATCH --error=/xdisk/haining/maarowosegbe/target_als/logs/slurm/%x-%j.err
#SBATCH --account=haining
#SBATCH --partition=standard
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4gb
#SBATCH --time=01:00:00

### Re-run ONLY the report rule (figures + report_index.md) after editing workflow/scripts/report.R.
### Snakemake does not track a changed script for a shell rule, so --forcerun report is needed.
### Everything upstream (aggregate tables) is reused, not recomputed.

set -eo pipefail

echo "========== Report rerun started at: $(date) =========="
echo "  Node    : $(hostname)"
echo "  Job ID  : ${SLURM_JOB_ID}"

SCRIPT_BASE=/home/u11/maarowosegbe/Target_ALS
DATA_BASE=/xdisk/haining/maarowosegbe/target_als
export MAMBA_ROOT_PREFIX=/groups/haining/maarowosegbe/micromamba
MC=/opt/ohpc/pub/apps/micromamba/2.0.2-2/bin/micromamba

cd "${SCRIPT_BASE}"

"${MC}" run -n snakemake_env \
  snakemake \
    --snakefile "${SCRIPT_BASE}/workflow/Snakefile" \
    --configfile "${SCRIPT_BASE}/config/config.yaml" \
    --profile "${SCRIPT_BASE}/workflow/profiles/slurm" \
    --forcerun report --latency-wait 60 --jobs 5 --printshellcmds \
  2>&1 | tee "${DATA_BASE}/logs/slurm/snakemake_report_${SLURM_JOB_ID}.log"

echo "========== Report rerun finished at: $(date) =========="
