#!/bin/bash
# --------------------------------------------------------------
### Request resources
# --------------------------------------------------------------
#SBATCH --job-name=target_als_prepare_refs
#SBATCH --output=/xdisk/haining/maarowosegbe/target_als/logs/slurm/%x-%j.out
#SBATCH --error=/xdisk/haining/maarowosegbe/target_als/logs/slurm/%x-%j.err
#SBATCH --account=haining
#SBATCH --partition=standard
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --mem-per-cpu=4gb
#SBATCH --time=04:00:00

# One-time references: snpEff GRCh38 database, gene BED from the matching Ensembl GTF, FASTA index.
# Run AFTER 01_setup_envs. Everything lands under /xdisk/haining/maarowosegbe/target_als/ref.
set -eo pipefail
export MAMBA_ROOT_PREFIX=/groups/haining/maarowosegbe/micromamba
MC=/opt/ohpc/pub/apps/micromamba/2.0.2-2/bin/micromamba
REF=/xdisk/haining/maarowosegbe/target_als/ref
SNPEFF_DB=GRCh38.105          # keep equal to annotation.snpeff_db in config/config.yaml
GTF_URL=https://ftp.ensembl.org/pub/release-105/gtf/homo_sapiens/Homo_sapiens.GRCh38.105.gtf.gz
mkdir -p "${REF}/snpeff_data"
cd /home/u11/maarowosegbe/Target_ALS

echo "== snpEff database ${SNPEFF_DB}"
"${MC}" run -n target_als_annotation snpEff download -dataDir "${REF}/snpeff_data" "${SNPEFF_DB}"

echo "== gene BED"
[[ -s "${REF}/Homo_sapiens.GRCh38.105.gtf.gz" ]] || wget -q -O "${REF}/Homo_sapiens.GRCh38.105.gtf.gz" "${GTF_URL}"
"${MC}" run -n target_als_core bash scripts/make_gene_bed.sh \
  "${REF}/Homo_sapiens.GRCh38.105.gtf.gz" "${REF}/genes.GRCh38.bed"

echo "== FASTA index (reused WGS-repo reference)"
FA=$(grep -E '^\s+fasta:' config/config.yaml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
[[ -s "${FA}.fai" ]] || "${MC}" run -n target_als_core samtools faidx "${FA}"
echo "done: $(date)"
