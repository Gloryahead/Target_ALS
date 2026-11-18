"""
Rule 05 - rare protein-altering variants in a user-supplied ALS gene list.
A variant qualifies when any snpEff ANN entry names a gene in the list with a consequence term in
rare_als.consequence_terms, and (only if annotation.gnomad_af_tag is set) AF < rare_als.af_max
(missing AF counts as rare). Outputs per subject:
  <subject>.rare_als.tsv         long table, category = gene, value = qualifying variants (feeds the aggregate)
  <subject>.rare_als.detail.tsv  PARTICIPANT-LEVEL variant list - stays on xdisk, never shared
Only gene x group carrier counts leave this stage (rule 10).
"""

_AF_TAG = (config["annotation"].get("gnomad_af_tag") or "")

rule rare_als_variants:
    input:
        vcf   = f"{STAGE_ROOT['rare']}/annotated/{{set}}/{{subject}}.ann.vcf.gz",
        genes = config["rare_als"]["gene_list"],
    output:
        table  = f"{STAGE_ROOT['rare']}/rare_als/{{set}}/{{subject}}.rare_als.tsv",
        detail = f"{STAGE_ROOT['rare']}/rare_als/{{set}}/{{subject}}.rare_als.detail.tsv",
    log: f"{LOGDIR}/rare_als/{{set}}/{{subject}}.log"
    threads: 1
    resources: mem_mb=4000, runtime=120
    params:
        activate = mamba_activate(ENVS["core"]),
        scripts  = SCRIPTS,
        terms    = ",".join(config["rare_als"]["consequence_terms"]),
        af_max   = config["rare_als"]["af_max"],
        af_fmt   = (f"\\t%INFO/{_AF_TAG}" if _AF_TAG else ""),
        af_flag  = ("--af-column" if _AF_TAG else ""),
    shell:
        """
        set -eo pipefail
        {params.activate}
        mkdir -p $(dirname {output.table})
        bcftools query -f '%CHROM\\t%POS\\t%REF\\t%ALT\\t%INFO/ANN{params.af_fmt}\\n' {input.vcf} 2>{log} \
          | python {params.scripts}/rare_als.py --set {wildcards.set} --subject {wildcards.subject} \
              --genes {input.genes} --terms {params.terms} --af-max {params.af_max} {params.af_flag} \
              --out {output.table} --detail {output.detail} 2>>{log}
        """
