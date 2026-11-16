#!/bin/bash
# Build the gene BED used for SV/CNV gene-overlap tallies from an Ensembl/GENCODE GTF.
#   usage: scripts/make_gene_bed.sh <annotation.gtf[.gz]> <out.bed>
# Output: chr-prefixed GRCh38, 0-based half-open, columns chrom start end gene_name; chr1-22,X,Y,M only
# (Ensembl 'MT' -> 'chrM'). Use the same release as annotation.snpeff_db (e.g. Ensembl 105 for GRCh38.105).
set -euo pipefail
GTF="$1"; OUT="$2"
CAT=cat; [[ "${GTF}" == *.gz ]] && CAT=zcat
${CAT} "${GTF}" | awk -F'\t' 'BEGIN{OFS="\t"}
  !/^#/ && $3=="gene" {
    c=$1; sub(/^chr/,"",c); if (c=="MT") c="M";
    if (c !~ /^([0-9]+|X|Y|M)$/) next;
    if (c ~ /^[0-9]+$/ && c+0>22) next;
    name="."; if (match($9, /gene_name "[^"]+"/)) { name=substr($9, RSTART+11, RLENGTH-12) }
    print "chr" c, $4-1, $5, name }' \
  | sort -k1,1V -k2,2n > "${OUT}"
echo "wrote $(wc -l < "${OUT}") genes to ${OUT}"
