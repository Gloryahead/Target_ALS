"""
Rule 08 - repeat-expansion table (C9orf72 and other loci) from the ExpansionHunter-style VCFs
(NYGC *.eh.vcf; DRAGEN *.repeats.vcf.gz). Loci and expansion thresholds come from config repeat_loci
(matched on INFO/REPID). Per subject: longest allele (FORMAT/REPCN) per locus and an expanded flag.
The NYGC eh.summary_table is carried in the sample sheet but not parsed in v1 (format unverified).
<subject>.repeats.detail.tsv is participant-level and stays on xdisk.
Focus-restricted if 'repeats' is in focus_regions.stages.
"""

rule repeat_table:
    input:
        vcf = f"{OUTDIR}/standardised/{{set}}/{{subject}}.repeats.vcf.gz",
        tbi = f"{OUTDIR}/standardised/{{set}}/{{subject}}.repeats.vcf.gz.tbi",
    output:
        table  = f"{STAGE_ROOT['repeats']}/repeats/{{set}}/{{subject}}.repeats.tsv",
        detail = f"{STAGE_ROOT['repeats']}/repeats/{{set}}/{{subject}}.repeats.detail.tsv",
    log: f"{LOGDIR}/repeats/{{set}}/{{subject}}.log"
    threads: 1
    resources: mem_mb=2000, runtime=30
    params:
        activate = mamba_activate("target_als_core"),
        scripts  = SCRIPTS,
        focus    = focus_args("repeats"),
        loci     = " ".join(f"{n}:{v['repid']}:{v['expanded_min']}" for n, v in config["repeat_loci"].items()),
    shell:
        """
        set -eo pipefail
        {params.activate}
        mkdir -p $(dirname {output.table})
        bcftools view -H {params.focus} {input.vcf} 2>{log} \
          | python {params.scripts}/repeats_table.py --set {wildcards.set} --subject {wildcards.subject} \
              --loci {params.loci} --out {output.table} --detail {output.detail} 2>>{log}
        """
