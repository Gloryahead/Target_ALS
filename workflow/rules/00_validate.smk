"""
Rule 00 - sample-sheet validation.
Fails fast (before any compute) if the private sheet is malformed or points at missing files.
Writes COUNTS ONLY (per set/group/product); no subject IDs or paths, so the file is safe to share.
Parse-time checks (unknown set, duplicate subject, control in the ALS-only long-read set, ...) are
in workflow/scripts/sheetlib.py and run every time Snakemake parses the Snakefile.
"""

def _all_sheet_files(wc=None):
    return [unit_path(s, subj, p)
            for s in SETS for p in sheetlib.PRODUCT_COLUMN
            for subj in subjects(s, p)]

rule validate_sample_sheet:
    input:
        sheet = config["samples"],
        files = _all_sheet_files,
    output:
        f"{OUTDIR}/qc/sample_sheet_check.txt",
    log: f"{LOGDIR}/validate/validate_sample_sheet.log"
    threads: 1
    resources: mem_mb=2000, runtime=15
    params:
        activate = mamba_activate(ENVS["core"]),
        scripts = SCRIPTS,
        # only the fields the validator needs (no filter expressions -> no quoting trouble)
        sets_json = json.dumps({k: {f: v[f] for f in ("site", "data_type", "groups")} | {"products": list(v["products"])}
                                for k, v in SETS.items()}),
    shell:
        """
        set -eo pipefail
        {params.activate}
        python {params.scripts}/validate_sample_sheet.py \
            --sheet {input.sheet} --sets-json '{params.sets_json}' --out {output} 2>{log}
        """
