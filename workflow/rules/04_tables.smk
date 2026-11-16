"""
Rule 04 - variant-type and consequence tables and the six-class substitution spectrum, per subject.
Reads the uniformly annotated VCF (snpEff ANN: first entry = most severe by snpEff's own ordering).
Tables emitted (long format): variant_type (SNV/INS/DEL/MNV/complex), consequence, impact,
substitution (C>A, C>G, C>T, T>A, T>C, T>G; purine references collapsed to the pyrimidine strand).
Counts are carrier counts (per-sample VCFs have no hom-ref calls). Never compare absolute counts across
sets: three callers, three filter systems.
"""

rule variant_tables:
    input:
        vcf = f"{STAGE_ROOT['variants']}/annotated/{{set}}/{{subject}}.ann.vcf.gz",
    output:
        f"{STAGE_ROOT['variants']}/tables/{{set}}/{{subject}}.variants.tsv",
    log: f"{LOGDIR}/tables/{{set}}/{{subject}}.variants.log"
    threads: 1
    resources: mem_mb=4000, runtime=120
    params:
        activate = mamba_activate("target_als_core"),
        scripts = SCRIPTS,
    shell:
        """
        set -eo pipefail
        {params.activate}
        mkdir -p $(dirname {output})
        bcftools query -f '%REF\\t%ALT\\t%INFO/ANN\\n' {input.vcf} 2>{log} \
          | python {params.scripts}/vcf_tables.py --set {wildcards.set} --subject {wildcards.subject} \
              --out {output} 2>>{log}
        """
