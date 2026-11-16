"""
Rule 02 - per-sample QC from the standardised small-variant VCF.
bcftools stats -s - gives record counts (SN), Ti/Tv (TSTV) and per-sample het/hom (PSC);
parse_bcftools_stats.py turns them into a long table: n_snps, n_indels, ts_tv, het_hom_ratio,
snv_indel_ratio, ... QC is always genome-wide (never focus-restricted).
"""

rule bcftools_stats:
    input:
        vcf = f"{OUTDIR}/standardised/{{set}}/{{subject}}.small.vcf.gz",
        tbi = f"{OUTDIR}/standardised/{{set}}/{{subject}}.small.vcf.gz.tbi",
    output:
        stats = f"{OUTDIR}/qc/{{set}}/{{subject}}.bcftools_stats.txt",
        table = f"{OUTDIR}/qc/{{set}}/{{subject}}.qc.tsv",
    log: f"{LOGDIR}/qc/{{set}}/{{subject}}.log"
    threads: 2
    resources: mem_mb=4000, runtime=60
    params:
        activate = mamba_activate("target_als_core"),
        scripts = SCRIPTS,
    shell:
        """
        set -eo pipefail
        {params.activate}
        bcftools stats -s - {input.vcf} > {output.stats} 2>{log}
        python {params.scripts}/parse_bcftools_stats.py \
            --stats {output.stats} --set {wildcards.set} --subject {wildcards.subject} \
            --out {output.table} 2>>{log}
        """
