"""
Rule 07 - CNV tallies per subject (Canvas for NYGC, DRAGEN CNV for Psomagen SR; no CNV product for
the long-read set). Same script as rule 06 with --kind cnv: class from SVTYPE, else from a symbolic
ALT, else (autosomes only) from FORMAT/CN (CN<2 loss, CN>2 gain); size bins; gene overlap.
Focus-restricted if 'cnv' is in focus_regions.stages.
"""

rule cnv_tally:
    input:
        vcf   = f"{OUTDIR}/standardised/{{set}}/{{subject}}.cnv.vcf.gz",
        tbi   = f"{OUTDIR}/standardised/{{set}}/{{subject}}.cnv.vcf.gz.tbi",
        genes = config["annotation"]["gene_bed"],
    output:
        f"{STAGE_ROOT['cnv']}/cnv/{{set}}/{{subject}}.cnv_tally.tsv",
    log: f"{LOGDIR}/cnv/{{set}}/{{subject}}.log"
    threads: 1
    resources: mem_mb=4000, runtime=60
    params:
        activate = mamba_activate(ENVS["core"]),
        scripts  = SCRIPTS,
        focus    = focus_args("cnv"),
        bins     = ",".join(map(str, config["cnv"]["size_bins"])),
    shell:
        """
        set -eo pipefail
        {params.activate}
        mkdir -p $(dirname {output})
        bcftools view -H {params.focus} {input.vcf} 2>{log} \
          | python {params.scripts}/sv_cnv_tally.py --kind cnv --set {wildcards.set} --subject {wildcards.subject} \
              --genes {input.genes} --bins {params.bins} --out {output} 2>>{log}
        """
