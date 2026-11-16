"""
Rule 01 - standardise each subject's VCFs, per set, never merged across sets.
  small variants : restrict to chr1-22,X,Y,M -> PASS + genotype filters (per set, config) ->
                   bcftools norm -m -any (split multiallelics, left-align against the GRCh38 FASTA)
  sv/cnv/repeats : restrict to the same contigs + the set's FILTER rule; no splitting/normalisation
All outputs are bgzipped + tabix-indexed under <outdir>/standardised/<set>/.
The input VCFs need not be indexed (everything streams; -t targets, not -r regions).
"""

rule standardise_small:
    input:
        vcf   = lambda wc: unit_path(wc.set, wc.subject, "small"),
        ref   = REF,
        valid = f"{OUTDIR}/qc/sample_sheet_check.txt",
    output:
        vcf = f"{OUTDIR}/standardised/{{set}}/{{subject}}.small.vcf.gz",
        tbi = f"{OUTDIR}/standardised/{{set}}/{{subject}}.small.vcf.gz.tbi",
    log: f"{LOGDIR}/standardise/{{set}}/{{subject}}.small.log"
    threads: 2
    resources: mem_mb=6000, runtime=240
    params:
        activate = mamba_activate("target_als_core"),
        contigs  = CONTIG_ARG,
        filt     = lambda wc: view_filter_args(wc.set, "small"),
    shell:
        """
        set -eo pipefail
        {params.activate}
        mkdir -p $(dirname {output.vcf})
        bcftools view {params.contigs} {params.filt} {input.vcf} 2>{log} \
          | bcftools norm -m -any -f {input.ref} -c w -Oz -o {output.vcf} 2>>{log}
        bcftools index -t {output.vcf} 2>>{log}
        """


rule standardise_other:
    input:
        vcf   = lambda wc: unit_path(wc.set, wc.subject, wc.product),
        valid = f"{OUTDIR}/qc/sample_sheet_check.txt",
    output:
        vcf = f"{OUTDIR}/standardised/{{set}}/{{subject}}.{{product}}.vcf.gz",
        tbi = f"{OUTDIR}/standardised/{{set}}/{{subject}}.{{product}}.vcf.gz.tbi",
    wildcard_constraints:
        product = "sv|cnv|repeats",
    log: f"{LOGDIR}/standardise/{{set}}/{{subject}}.{{product}}.log"
    threads: 1
    resources: mem_mb=4000, runtime=60
    params:
        activate = mamba_activate("target_als_core"),
        contigs  = CONTIG_ARG,
        filt     = lambda wc: view_filter_args(wc.set, wc.product),
    shell:
        """
        set -eo pipefail
        {params.activate}
        mkdir -p $(dirname {output.vcf})
        bcftools view {params.contigs} {params.filt} -Oz -o {output.vcf} {input.vcf} 2>{log}
        bcftools index -t {output.vcf} 2>>{log}
        """
