"""
Rule 06 - structural-variant tallies per subject: SVTYPE, size bins, gene overlap.
Input is the standardised SV VCF (Manta for NYGC, DRAGEN SV for Psomagen SR, pbsv for Psomagen LR).
Gene overlap = SV interval intersects any interval in annotation.gene_bed (bedtools intersect -u).
Breakends (BND) and records without a size get size bin 'NA'. Focus-restricted if 'sv' is in
focus_regions.stages (bcftools -T streaming; records overlapping the focus BED are kept).
"""

rule sv_tally:
    input:
        vcf   = f"{OUTDIR}/standardised/{{set}}/{{subject}}.sv.vcf.gz",
        tbi   = f"{OUTDIR}/standardised/{{set}}/{{subject}}.sv.vcf.gz.tbi",
        genes = config["annotation"]["gene_bed"],
    output:
        f"{STAGE_ROOT['sv']}/sv/{{set}}/{{subject}}.sv_tally.tsv",
    log: f"{LOGDIR}/sv/{{set}}/{{subject}}.log"
    threads: 1
    resources: mem_mb=4000, runtime=60
    params:
        activate = mamba_activate(ENVS["core"]),
        scripts  = SCRIPTS,
        focus    = focus_args("sv"),
        bins     = ",".join(map(str, config["sv"]["size_bins"])),
    shell:
        """
        set -eo pipefail
        {params.activate}
        mkdir -p $(dirname {output})
        bcftools view -H {params.focus} {input.vcf} 2>{log} \
          | python {params.scripts}/sv_cnv_tally.py --kind sv --set {wildcards.set} --subject {wildcards.subject} \
              --genes {input.genes} --bins {params.bins} --out {output} 2>>{log}
        """
