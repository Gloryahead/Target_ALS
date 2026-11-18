"""
Rule 09 - cross-site concordance for any subject present in both sets of a configured pair
(default nygc_sr vs psomagen_sr). This COMPARES two sets' standardised small-variant VCFs for the same
subject with bcftools isec (exact CHROM/POS/REF/ALT match); it never merges them into one call set.
Counts: only_<A>, only_<B>, shared. Different callers/filters -> expect disagreement; the number is a
descriptive reproducibility indicator, not an error rate. Site-level concordance only (no genotype
comparison in v1).
"""

rule concordance_pair:
    input:
        a = lambda wc: f"{OUTDIR}/standardised/{PAIRS[wc.set]['a']}/{wc.subject}.small.vcf.gz",
        b = lambda wc: f"{OUTDIR}/standardised/{PAIRS[wc.set]['b']}/{wc.subject}.small.vcf.gz",
        a_tbi = lambda wc: f"{OUTDIR}/standardised/{PAIRS[wc.set]['a']}/{wc.subject}.small.vcf.gz.tbi",
        b_tbi = lambda wc: f"{OUTDIR}/standardised/{PAIRS[wc.set]['b']}/{wc.subject}.small.vcf.gz.tbi",
    output:
        f"{STAGE_ROOT['concordance']}/concordance/{{set}}/{{subject}}.counts.tsv",
    log: f"{LOGDIR}/concordance/{{set}}/{{subject}}.log"
    threads: 2
    resources: mem_mb=6000, runtime=120
    params:
        activate = mamba_activate(ENVS["core"]),
        focus    = focus_args_isec("concordance"),
        name_a   = lambda wc: PAIRS[wc.set]["a"],
        name_b   = lambda wc: PAIRS[wc.set]["b"],
    shell:
        """
        set -eo pipefail
        {params.activate}
        T=$(mktemp -d)
        trap 'rm -rf "$T"' EXIT
        bcftools isec {params.focus} -p "$T" -Oz {input.a} {input.b} 2>{log}
        # 0000 = only in A, 0001 = only in B, 0002 = shared (A's records)
        n() {{ bcftools view -H "$T/$1.vcf.gz" | wc -l; }}
        mkdir -p $(dirname {output})
        {{
          printf 'set\\tsubject\\ttable\\tcategory\\tvalue\\n'
          printf '%s\\t%s\\tconcordance\\tonly_%s\\t%s\\n' {wildcards.set} {wildcards.subject} {params.name_a} "$(n 0000)"
          printf '%s\\t%s\\tconcordance\\tonly_%s\\t%s\\n' {wildcards.set} {wildcards.subject} {params.name_b} "$(n 0001)"
          printf '%s\\t%s\\tconcordance\\tshared\\t%s\\n'  {wildcards.set} {wildcards.subject} "$(n 0002)"
          printf '%s\\t%s\\t__subject__\\t__subject__\\t1\\n' {wildcards.set} {wildcards.subject}
        }} > {output}
        """
