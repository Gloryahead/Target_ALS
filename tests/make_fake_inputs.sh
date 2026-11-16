#!/bin/bash
# Create EMPTY placeholder input files named in tests/samples.fake.tsv (plus a fake reference and gene BED)
# so `snakemake -n` can resolve inputs. No real data, no real IDs. Run from the repo root.
set -euo pipefail
mkdir -p tests/fake/ref
: > tests/fake/ref/genome.fa
: > tests/fake/ref/genes.bed
grep -v '^#' tests/samples.fake.tsv | tail -n +2 | cut -f5- | tr '\t' '\n' | grep -v '^$' | while read -r f; do
  mkdir -p "$(dirname "$f")"; : > "$f"
done
echo "fake inputs created under tests/fake/"
