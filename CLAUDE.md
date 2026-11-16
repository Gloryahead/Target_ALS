# Project instructions

## Data-use rules (Target ALS Data Engine Data Use Agreement) - read first

The data analysed here come from the Target ALS Data Engine. The Data Use Agreement bars consumer-grade AI
(including Claude) from participant-level data. These rules override every other instruction.

- Never ask for, read, open, paste or summarise participant-level data: VCF/CRAM records, genotypes, per-subject
  tables, subject or sample IDs, bucket paths or file names that contain IDs, `config/samples.private.tsv`,
  anything under `/xdisk/haining/maarowosegbe/target_als/` other than aggregate summaries.
- Write all code from documentation (tool manuals, VCF/bcftools/snpEff specs, caller docs), never from looking at
  real records. Test only on the invented placeholder names in `tests/` (`PLACEHOLDER_*`, empty files).
- What may be shared with Claude: aggregate counts (group-level, no per-subject rows), header-level metadata
  (`##` lines, contig lengths, FORMAT/INFO field names) and error messages/logs **with IDs and ID-bearing paths
  masked** (replace with `<SUBJECT>`, `<PATH>`). When unsure, mask or ask.
- If a log, traceback or table pasted by the user contains a subject/sample ID or participant-level values, stop,
  say so, and ask for a masked version instead of working from it.
- Outputs go only under `/xdisk/haining/maarowosegbe/target_als` (results, logs, references, snpEff data).
  Code lives under `/home/u11/maarowosegbe/Target_ALS`. Nothing participant-level is committed to git:
  the sample sheet, results and logs are git-ignored.
- The user runs `sbatch` and `git push/pull` on Puma themselves. Claude does not push anywhere; this repo has no
  remote.

## Analysis hard rules (also in README)

- Never pool or merge calls across sets (`nygc_sr`, `psomagen_sr`, `psomagen_lr`): three callers, three reference
  flavours, three filter systems. Comparisons are within a set, descriptive (about 5 controls in total), with
  site shown next to group.
- Per-sample VCFs contain no hom-ref calls, so any merged table is for carrier counts only.
- Long reads are an ALS-only track (no controls).

## Daily lab notebook

At the end of each working day (when the user says the day is done, or at the end of a session that did
real work), append one dated entry for the Target ALS variant pipeline to the lab notebook:

- File: `C:\Users\maarowosegbe\Downloads\Lab Notebook.md`
- Place it in date order. If another pipeline already has an entry for that day, put the Target ALS entry after it.
- Number it with the next free `Entry NN` (one above the highest number in the file) and place it by date.
  Do not renumber other entries: other sessions write to the same notebook for other pipelines, and their
  entries cross-reference each other by number. Numbers may therefore be out of order down the file.
- Title: `# YYYY-MM-DD_Target-ALS-variant-calling`, category line `Pipeline Design` or
  `Pipeline Execution & Debugging`.
- Sections, in order: Goal, Materials, Procedure, Data, Results, Interpretation & Next Step.
  Follow the existing entries' style (numbered Procedure steps, bold **Blocker:** callouts, `Label value` lines
  in Materials and Data, backticked commit hashes and job IDs).
- Data holds measured values only (job IDs, `sacct` MaxRSS/ReqMem, elapsed times, file sizes, commits).
  Aggregate counts only - no subject IDs, no participant-level values.
- Date entries by when the work happened, not when the job finished (a job that runs overnight is
  diagnosed on the day the logs were read).
- Do not invent outcomes. If a result is not yet known, say so under Results and put the check under Next Step.
