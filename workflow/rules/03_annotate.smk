"""
Rule 03 - uniform annotation of ALL small variants with snpEff, so the three callers' consequences are
comparable (same transcript set, same terms). Optional gnomAD / ClinVar hooks via bcftools annotate
(paths in config annotation.*; leave "" to skip). Focus-restricted if 'annotate' is in
focus_regions.stages.
"""

_AN = config["annotation"]
_ANN_ROOT = STAGE_ROOT["annotate"]

rule annotate_snpeff:
    input:
        vcf = f"{OUTDIR}/standardised/{{set}}/{{subject}}.small.vcf.gz",
        tbi = f"{OUTDIR}/standardised/{{set}}/{{subject}}.small.vcf.gz.tbi",
    output:
        vcf = temp(f"{_ANN_ROOT}/annotated/{{set}}/{{subject}}.snpeff.vcf.gz"),
    log: f"{LOGDIR}/annotate/{{set}}/{{subject}}.snpeff.log"
    threads: 2
    resources: mem_mb=_AN["snpeff_mem_mb"] + 2000, runtime=360
    params:
        # snpEff/bgzip come from the annotation env (the WGS repo's wgs_annotation_env has no bcftools),
        # so bcftools is called from the core env through `micromamba run`.
        activate = mamba_activate(ENVS["annotation"]),
        bcftools = f'{_MAMBA_EXE} run -n {ENVS["core"]} bcftools',
        focus    = focus_args("annotate"),
        db       = _AN["snpeff_db"],
        datadir  = _AN["snpeff_data_dir"],
        extra    = _AN.get("snpeff_extra", ""),
        xmx      = _AN["snpeff_mem_mb"],
    shell:
        """
        set -eo pipefail
        {params.activate}
        mkdir -p $(dirname {output.vcf})
        {params.bcftools} view {params.focus} {input.vcf} 2>{log} \
          | snpEff -Xmx{params.xmx}m ann -noStats -dataDir {params.datadir} {params.extra} {params.db} 2>>{log} \
          | bgzip -c > {output.vcf}
        """


rule annotate_databases:
    """gnomAD / ClinVar hooks. With neither configured this just copies + indexes the snpEff output."""
    input:
        vcf = f"{_ANN_ROOT}/annotated/{{set}}/{{subject}}.snpeff.vcf.gz",
    output:
        vcf = f"{_ANN_ROOT}/annotated/{{set}}/{{subject}}.ann.vcf.gz",
        tbi = f"{_ANN_ROOT}/annotated/{{set}}/{{subject}}.ann.vcf.gz.tbi",
    log: f"{LOGDIR}/annotate/{{set}}/{{subject}}.databases.log"
    threads: 2
    resources: mem_mb=6000, runtime=120
    params:
        activate  = mamba_activate(ENVS["core"]),
        gnomad   = _AN.get("gnomad_vcf", "") or "",
        gnomad_c  = _AN.get("gnomad_columns", ""),
        clinvar   = _AN.get("clinvar_vcf", "") or "",
        clinvar_c = _AN.get("clinvar_columns", ""),
    shell:
        """
        set -eo pipefail
        {params.activate}
        STEP={output.vcf}.step
        bcftools index -t -f {input.vcf} 2>{log}
        CUR={input.vcf}
        if [ -n "{params.gnomad}" ]; then
            bcftools annotate -a {params.gnomad} -c {params.gnomad_c} -Oz -o ${{STEP}}1.vcf.gz $CUR 2>>{log}
            bcftools index -t ${{STEP}}1.vcf.gz 2>>{log}
            CUR=${{STEP}}1.vcf.gz
        fi
        if [ -n "{params.clinvar}" ]; then
            bcftools annotate -a {params.clinvar} -c {params.clinvar_c} -Oz -o ${{STEP}}2.vcf.gz $CUR 2>>{log}
            bcftools index -t ${{STEP}}2.vcf.gz 2>>{log}
            CUR=${{STEP}}2.vcf.gz
        fi
        cp $CUR {output.vcf}
        bcftools index -t -f {output.vcf} 2>>{log}
        rm -f {input.vcf}.tbi ${{STEP}}1.vcf.gz ${{STEP}}1.vcf.gz.tbi ${{STEP}}2.vcf.gz ${{STEP}}2.vcf.gz.tbi
        """
