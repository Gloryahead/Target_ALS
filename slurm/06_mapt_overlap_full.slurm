#!/bin/bash
# --------------------------------------------------------------
### Request resources
# --------------------------------------------------------------
#SBATCH --job-name=target_als_full_mapt
#SBATCH --output=/xdisk/haining/maarowosegbe/target_als_full/logs/slurm/%x-%j.out
#SBATCH --error=/xdisk/haining/maarowosegbe/target_als_full/logs/slurm/%x-%j.err
#SBATCH --account=haining
#SBATCH --partition=standard
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4gb
#SBATCH --time=02:00:00

### MAPT 3' UTR target-variant overlap on the FULL-TABLE run. Run AFTER slurm/04_pipeline_full.slurm has finished.
###   1) check_target_variants.py : carriers per variant per set x group (counts only) + per-subject file
###   2) summarise_people.py      : people-level all / some / none per set and across set pairs (counts only)
### The job log holds COUNTS ONLY. The per-subject file holds real subject IDs: it stays on xdisk (private,
### never paste it). Needs config/tau_targets.private.tsv on Puma (git-ignored, not in the repo).

set -eo pipefail
echo "========== MAPT overlap started at: $(date) =========="
echo "  Node    : $(hostname)"
echo "  Job ID  : ${SLURM_JOB_ID}"

SCRIPT_BASE=/home/u11/maarowosegbe/Target_ALS
DATA_BASE=/xdisk/haining/maarowosegbe/target_als_full
R="${DATA_BASE}/results"
OUT="${R}/mapt_overlap"
TARGETS="${SCRIPT_BASE}/config/tau_targets.private.tsv"
SHEET="${SCRIPT_BASE}/config/samples_full.private.tsv"
export MAMBA_ROOT_PREFIX=/groups/haining/maarowosegbe/micromamba
MC=/opt/ohpc/pub/apps/micromamba/2.0.2-2/bin/micromamba

[ -f "${TARGETS}" ] || { echo "missing ${TARGETS} (private targets file, copy it to Puma)"; exit 1; }
[ -f "${SHEET}" ]   || { echo "missing ${SHEET} (run slurm/03_build_sample_sheet_full.slurm)"; exit 1; }
[ -d "${R}/standardised" ] || { echo "missing ${R}/standardised (the pipeline has not finished)"; exit 1; }
for s in nygc_sr psomagen_sr psomagen_lr; do
  echo "  standardised/${s}: $(ls "${R}/standardised/${s}" 2>/dev/null | wc -l) files"
done

mkdir -p "${OUT}"
cd "${SCRIPT_BASE}"

echo "---- 1) carriers per variant (counts only) ----"
"${MC}" run -n wgs_env python scripts/check_target_variants.py \
  --sheet "${SHEET}" --standardised "${R}/standardised" --targets "${TARGETS}" \
  --out "${OUT}/target_variant_carriers.tsv" \
  --out-combo "${OUT}/target_variant_combos.tsv" \
  --out-subject "${OUT}/per_subject.private.tsv" --with-ids
echo "rows in target_variant_carriers.tsv: $(($(wc -l < "${OUT}/target_variant_carriers.tsv") - 1))"

echo "---- 2) people-level summary (counts only) ----"
"${MC}" run -n wgs_env python scripts/summarise_people.py "${OUT}/per_subject.private.tsv" \
  --out "${OUT}/people_summary.txt"
cat "${OUT}/people_summary.txt"

echo "========== MAPT overlap finished at: $(date) =========="
