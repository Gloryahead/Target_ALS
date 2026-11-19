"""
Rule 10 - aggregation and report (aggregate tables and figures only).

aggregate: per set (never across sets) and stage, collapse the per-subject long tables into
  <root>/aggregate/<set>/<stage>.summary.tsv   group x site x table x category: n_subjects, n_nonzero,
                                               sum, mean, median, min, max   (no subject IDs)
  <root>/aggregate/<set>/<stage>.points.tsv    per-subject values under pseudonyms (e.g. nygc_sr-ALS-03)
Absent categories count as 0 (valid for carrier-count tables only; per-sample VCFs have no hom-ref calls).

report: figures + report_index.md built from the summaries/points only (R, no IDs).
"""

def _site_label(set_name):
    return SETS[set_name]["site"] if set_name in SETS else "cross-site"

rule aggregate:
    input:
        tables = lambda wc: per_subject_tables(wc.stage, wc.set),
    output:
        summary = f"{{root}}/aggregate/{{set}}/{{stage}}.summary.tsv",
        points  = f"{{root}}/aggregate/{{set}}/{{stage}}.points.tsv",
    wildcard_constraints:
        root = "|".join(sorted({re.escape(OUTDIR), re.escape(FOCUS_ROOT)})),
    # {root} (an absolute path) must appear in the log too, or Snakemake rejects the rule
    log: f"{LOGDIR}/aggregate{{root}}/{{set}}.{{stage}}.log"
    threads: 1
    resources: mem_mb=4000, runtime=30
    params:
        activate = mamba_activate(ENVS["core"]),
        scripts  = SCRIPTS,
        sheet    = config["samples"],
        site     = lambda wc: _site_label(wc.set),
        dtype    = lambda wc: SETS[wc.set]["data_type"] if wc.set in SETS else "",
    shell:
        """
        set -eo pipefail
        {params.activate}
        python {params.scripts}/aggregate.py --sheet {params.sheet} --set {wildcards.set} \
            --site "{params.site}" --data-type "{params.dtype}" --stage {wildcards.stage} \
            --summary {output.summary} --points {output.points} {input.tables} 2>{log}
        """


rule report:
    input:
        aggregate_targets(),
    output:
        index = f"{REPORT_DIR}/report_index.md",
    log: f"{LOGDIR}/report/report.log"
    threads: 1
    resources: mem_mb=8000, runtime=30
    params:
        activate = mamba_activate(ENVS["r"]),
        scripts  = SCRIPTS,
        roots    = " ".join(f"{s}={STAGE_ROOT[s]}" for s in ACTIVE_STAGES),
        outdir   = REPORT_DIR,
    shell:
        """
        set -eo pipefail
        {params.activate}
        mkdir -p {params.outdir}
        Rscript {params.scripts}/report.R --roots {params.roots} --outdir {params.outdir} 2>{log}
        """
