#!/bin/bash
# --------------------------------------------------------------
### Request resources
# --------------------------------------------------------------
#SBATCH --job-name=tals_download_full
#SBATCH --output=/xdisk/haining/maarowosegbe/target_als_full/logs/slurm/%x-%j.out
#SBATCH --error=/xdisk/haining/maarowosegbe/target_als_full/logs/slurm/%x-%j.err
#SBATCH --account=haining
#SBATCH --partition=standard
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --time=06:00:00

# Download the files listed in uris_*.txt (written by the Jupyter cell, ~92 GB) into one folder per list.
# The buckets are REQUESTER-PAYS: set your billing project in the environment, not in this file:
#     export TALS_BILLING_PROJECT=<your gcp project id>      # then: sbatch --export=ALL slurm/00_download_full.slurm
# `-n` skips files that already exist, so the job can be re-run. One failed list does not stop the others.
# Do ONE file by hand first (see README), and check the cost.
set -o pipefail
: "${TALS_BILLING_PROJECT:?set TALS_BILLING_PROJECT (and submit with --export=ALL)}"
export MAMBA_ROOT_PREFIX=/groups/haining/maarowosegbe/micromamba
MC=/opt/ohpc/pub/apps/micromamba/2.0.2-2/bin/micromamba
LISTDIR=/xdisk/haining/maarowosegbe/target_als_full/lists
OUT=/xdisk/haining/maarowosegbe/target_als_full/vcfs

for f in "${LISTDIR}"/uris_*.txt; do
  name=$(basename "$f" .txt); name=${name#uris_}
  mkdir -p "${OUT}/${name}"
  echo "== ${name}: $(wc -l < "$f") files listed"
  ${MC} run -n gcloud_env gcloud storage cp -n --billing-project="${TALS_BILLING_PROJECT}" -I "${OUT}/${name}/" < "$f" \
    || echo "!! ${name}: gcloud returned an error"
  echo "== ${name}: $(ls "${OUT}/${name}" | wc -l) files present"
done
echo "== done"
du -sh "${OUT}"/*
