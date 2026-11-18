#!/bin/bash
# --------------------------------------------------------------
### Request resources
# --------------------------------------------------------------
#SBATCH --job-name=target_als_check_envs
#SBATCH --output=/xdisk/haining/maarowosegbe/target_als/logs/slurm/%x-%j.out
#SBATCH --error=/xdisk/haining/maarowosegbe/target_als/logs/slurm/%x-%j.err
#SBATCH --account=haining
#SBATCH --partition=standard
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --mem-per-cpu=4gb
#SBATCH --time=00:20:00

# Verify the environments this pipeline REUSES (no new envs are built except snakemake_env, already
# done). Prints tool versions only. Needs: wgs_env, wgs_annotation_env, wgs_r_env, snakemake_env.
#   mkdir -p /xdisk/haining/maarowosegbe/target_als/logs/slurm      # before sbatch
set -uo pipefail
export MAMBA_ROOT_PREFIX=/groups/haining/maarowosegbe/micromamba
MC=/opt/ohpc/pub/apps/micromamba/2.0.2-2/bin/micromamba
fail=0
chk() { # env, label, command...
  local env=$1 label=$2; shift 2
  if out=$("${MC}" run -n "${env}" "$@" 2>&1 | head -2 | tr '\n' ' '); [[ -n "${out}" ]]; then
    echo "OK   ${env}: ${label}: ${out}"
  else
    echo "FAIL ${env}: ${label}"; fail=1
  fi
}
chk wgs_env bcftools bcftools --version
chk wgs_env samtools samtools --version
chk wgs_env bedtools bedtools --version
chk wgs_env python python --version
chk wgs_annotation_env snpEff snpEff -version
chk wgs_annotation_env bgzip bgzip --version
chk wgs_r_env R-packages Rscript -e 'for (p in c("dplyr","readr","ggplot2","stringr","optparse")) library(p, character.only=TRUE); cat("ok")'
chk snakemake_env snakemake snakemake --version
chk snakemake_env pyyaml python -c 'import yaml; print(yaml.__version__)'
[[ ${fail} -eq 0 ]] && echo "ALL ENVIRONMENTS OK" || { echo "SOME CHECKS FAILED"; exit 1; }
