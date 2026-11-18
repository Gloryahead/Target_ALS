# Target ALS variant-call pipeline

Snakemake + SLURM pipeline (UA Puma, account `haining`) that analyses **pre-called** WGS variant files from
the Target ALS Data Engine: ALS vs non-neurological controls, small variants, SVs, CNVs and repeat
expansions. No alignment or calling happens here. Same conventions as the sibling
`WGS_variant_pipeline` repo (micromamba envs, `workflow/profiles/slurm`, `slurm/*.slurm`).

> **Data Use Agreement.** Participant-level data must never reach consumer-grade AI. Read
> [CLAUDE.md](CLAUDE.md). The sample sheet, results and logs are git-ignored; the code was written from
> documentation and tested only on invented `PLACEHOLDER_*` names (`tests/`).

## Hard rules (baked into the design)

1. **Never pool or merge calls across sets.** Three sets = three callers/filter systems/reference flavours:
   `nygc_sr` (GATK HaplotypeCaller + VQSR), `psomagen_sr` (DRAGEN), `psomagen_lr` (DeepVariant-style +
   pbsv). Every table, plot and aggregate is per set. The only cross-set step is rule 09, which
   *compares* the same subject's two call sets (bcftools isec) and writes counts; it does not merge.
2. **Per-sample VCFs contain no hom-ref calls**, so any merged/aggregated table is for *carrier counts
   only*. Aggregation treats a missing category as 0; never read it as "reference genotype".
3. **Comparisons are within a set and descriptive.** There are about 5 controls in total (all short read):
   report counts, fractions and per-subject points, with **site shown beside group** (site is confounded
   with group in places). No significance tests.
4. **Long reads are an ALS-only track** (`psomagen_lr`). A control row in that set is rejected at parse time.
5. All GRCh38, chr-prefixed contigs; analysis restricted to chr1-22, X, Y, M.

## Layout

```
CLAUDE.md                      data-use rules + daily lab-notebook rule
config/config.yaml             3 SETS (caller, globs per product, filters), annotation, focus_regions
config/als_genes.example.txt   EXAMPLE gene list (replace); rare_als.gene_list points at it
config/samples.private.tsv     PRIVATE sample sheet (git-ignored; built by scripts/build_sample_sheet.py)
environments/00_snakemake.yml    snakemake_env only; other envs are REUSED from the WGS repo (config `envs`)
slurm/01..04_*.slurm           check envs, prepare refs, build sample sheet, run pipeline
scripts/                       build_sample_sheet.py, make_gene_bed.sh
workflow/Snakefile             sample-sheet parsing, focus-region logic, rule all
workflow/rules/00..10_*.smk    the stages below
workflow/scripts/              python/R helpers (counts-only outputs)
workflow/profiles/slurm/       SLURM executor profile
tests/                         invented-placeholder sample sheet + dry-run scripts
docs/DESIGN.md                 design notes and open questions
```

## Stages

| Rule file | Stage | Output (under `/xdisk/haining/maarowosegbe/target_als/results`) |
|---|---|---|
| 00 | sample-sheet validation (counts only) | `qc/sample_sheet_check.txt` |
| 01 | standardise: chr1-22,X,Y,M; PASS + genotype filters per set; `bcftools norm -m -any -f` (small variants) | `standardised/<set>/<subject>.<product>.vcf.gz` |
| 02 | per-sample QC (`bcftools stats`): counts, Ti/Tv, het/hom, SNV:indel | `qc/<set>/` |
| 03 | uniform snpEff annotation of all small variants (+ optional gnomAD / ClinVar) | `annotated/<set>/*.ann.vcf.gz` |
| 04 | variant-type, consequence, impact and six-class substitution tables | `tables/<set>/` |
| 05 | rare protein-altering variants in a user-supplied ALS gene list | `rare_als/<set>/` |
| 06 | SV tallies: SVTYPE, size bins, gene overlap | `sv/<set>/` |
| 07 | CNV tallies (short-read sets only) | `cnv/<set>/` |
| 08 | repeat-expansion table (C9orf72 etc. from the ExpansionHunter-style VCFs) | `repeats/<set>/` |
| 09 | cross-site concordance for subjects present in both sets of a configured pair | `concordance/<pair>/` |
| 10 | aggregate (group x site summaries, pseudonymised points) + report | `aggregate/<set>/`, `report/` |

Per-subject tables and `*.detail.tsv` files hold participant-level rows and stay on xdisk. **Only the
group-level `*.summary.tsv`, the figures and `report_index.md` are candidates for sharing**, and even
those should be checked against the DUA before leaving the enclave of your own accounts.

## Run order (on Puma, by you)

```bash
mkdir -p /xdisk/haining/maarowosegbe/target_als/logs/slurm      # SLURM cannot create the log dir
cd /home/u11/maarowosegbe/Target_ALS
sbatch slurm/01_check_envs.slurm            # verifies the reused WGS envs + snakemake_env (no new envs)
sbatch slurm/02_prepare_refs.slurm          # snpEff GRCh38 DB, gene BED, FASTA index (once)
sbatch slurm/03_build_sample_sheet.slurm    # writes config/samples.private.tsv; log = counts only
```

Check the per-set counts in the `03` log against the download inventory, edit
`sample_sheet.subject_regex` / globs in `config/config.yaml` if a count is off, rerun `03`. Edit
`config/als_genes.example.txt` (or point `rare_als.gene_list` at your own list). Then:

```bash
sbatch slurm/04_pipeline.slurm              # dry run first (stops on error), then the full run
```

### Dry run

```bash
micromamba activate snakemake_env
cd /home/u11/maarowosegbe/Target_ALS
snakemake -n --profile workflow/profiles/slurm
```

Repo self-test on invented placeholder names (empty files, no real data; works on any machine with
Snakemake):

```bash
bash tests/run_dry_run.sh        # == snakemake -n --configfile config/config.yaml tests/config.fake.yaml
```

### Focus regions (e.g. MAPT 3' UTR)

Set `focus_regions.bed` (chr-prefixed GRCh38 BED, 0-based) and a `label` in `config/config.yaml`; the
listed stages (`annotate, variants, rare, sv, cnv, repeats, concordance`) are then run on those regions
only (bcftools `-T` streaming), write under `<outdir>/focus_<label>/`, and `rule all` requests only
those stages. Standardise and QC stay genome-wide and are shared. Get the coordinates from a public
annotation; none are hard-coded here.

## Notes on privacy of logs

Snakemake job names, log file names and some error messages contain subject IDs. Before sharing any log,
mask IDs and paths (`<SUBJECT>`, `<PATH>`); the validation, sample-sheet and aggregate outputs are
written to avoid IDs. See [CLAUDE.md](CLAUDE.md).

Open design questions: [docs/DESIGN.md](docs/DESIGN.md).
