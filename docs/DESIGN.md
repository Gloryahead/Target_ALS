# Design notes and open questions

## Decisions already made (by the user)
- New, separate repo (this one); uniform snpEff re-annotation of all small variants; long reads as an
  ALS-only track; later focus on the MAPT 3' UTR (config `focus_regions`).
- One CRAM-only NYGC subject has no VCFs and is excluded automatically (no `small_vcf` -> not written by
  `build_sample_sheet.py`).

## How the pieces fit
- A subject is a row per **set**; `(site, data_type)` selects the set. The same subject can appear in
  `nygc_sr` and `psomagen_sr`; those are separate units and are only ever compared in rule 09.
- Every per-subject stage writes a long table `set, subject, table, category, value` plus a `__subject__`
  row; `aggregate.py` turns these into group x site summaries and pseudonymised points per set.
- Standardise is genome-wide and shared; focus regions only restrict downstream stages and move their
  outputs to `focus_<label>/`.

## Open design questions
1. **Subject-ID extraction.** `sample_sheet.subject_regex` assumes the ID is the file-name prefix before the
   first `.` or `_`. Verify (on masked names) that the same subject gets the same ID across NYGC/Psomagen;
   rule 09 depends on it.
2. **eh.summary_table (NYGC)** is carried in the sheet but not parsed (its columns are unverified). Share
   only its masked header line if you want it integrated.
3. **FILTER semantics for repeat VCFs** (ExpansionHunter / DRAGEN repeats): `pass_only: false` for now.
4. **Repeat thresholds** in `repeat_loci` (C9orf72 30, ATXN2 33) are placeholders to verify against
   the literature and your variant catalog's REPIDs.
5. **snpEff database** `GRCh38.105` uses Ensembl contig names; snpEff normally tolerates the `chr` prefix, but
   confirm on the first run (warnings about unknown chromosomes in the snpEff log, counts of
   `no_annotation`). ClinVar's GRCh38 VCF has bare contig names: make a chr-renamed copy
   (`bcftools annotate --rename-chrs`) before setting `clinvar_vcf`.
6. **Reference FASTA** is reused from the WGS repo (Broad hg38, chr-prefixed). Only used for left-alignment.
7. **gnomAD AF filter** in rule 05 only activates when `gnomad_af_tag` is set; otherwise "rare" is not
   enforced and the table is protein-altering variants in the gene list only.
8. **Small-cell disclosure.** Group-level counts of carriers in a gene can equal 1 subject. Confirm whether
   the DUA requires small-cell suppression before any table leaves your own accounts.
9. **Concordance** is site-level (CHROM/POS/REF/ALT) only; genotype concordance and a long-read-vs-short-read
   pair (commented in the config) can be added.
10. **Per-subject outputs on xdisk** contain IDs by design (needed to join to the sheet); only aggregates are
    meant to be shared.
11. `bcftools -i 'FMT/DP>=10 && FMT/GQ>=20'` drops records with missing DP/GQ; NYGC VQSR VCFs are expected
    to carry both, DRAGEN hard-filtered VCFs are filtered on PASS only (as specified).
12. Not yet exercised on a real Snakemake install on this machine (no Snakemake here): the dry-run logic
    was checked by a stand-in harness; run `bash tests/run_dry_run.sh` once in `snakemake_env`.
13. **Reused environments.** The pipeline uses wgs_env (bcftools/samtools/bedtools/python), wgs_annotation_env (snpEff, bgzip) and wgs_r_env (tidyverse, optparse) from the WGS repo to save space (names in config `envs`). snpEff rule calls bcftools via `micromamba run -n wgs_env` because wgs_annotation_env has no bcftools. Run slurm/01_check_envs.slurm to confirm every tool is present.
