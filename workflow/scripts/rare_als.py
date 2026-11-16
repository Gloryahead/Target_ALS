#!/usr/bin/env python3
"""Rule 05: rare protein-altering variants in a user-supplied gene list, one subject.

stdin: `bcftools query -f '%CHROM\\t%POS\\t%REF\\t%ALT\\t%INFO/ANN[\\t%INFO/<AF tag>]\\n'`
A variant is counted once per gene when any ANN entry has Gene_Name in the list and an annotation term
in --terms; with --af-column it must also have AF < --af-max (missing AF counts as rare).
--out    long table (category = gene, value = number of qualifying variants)  -> aggregated later
--detail participant-level variant list -> stays on xdisk, never shared
"""
import argparse
import sys
from collections import Counter


def read_genes(path):
    with open(path) as fh:
        return {ln.strip() for ln in fh if ln.strip() and not ln.startswith("#")}


def first_af(text):
    if text in (".", ""):
        return None
    try:
        return float(text.split(",")[0])
    except ValueError:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--set", required=True)
    ap.add_argument("--subject", required=True)
    ap.add_argument("--genes", required=True)
    ap.add_argument("--terms", required=True, help="comma-separated snpEff annotation terms")
    ap.add_argument("--af-max", type=float, default=0.001)
    ap.add_argument("--af-column", action="store_true", help="a 6th column holds the population AF")
    ap.add_argument("--out", required=True)
    ap.add_argument("--detail", required=True)
    a = ap.parse_args()

    genes, terms = read_genes(a.genes), set(a.terms.split(","))
    per_gene = Counter()
    with open(a.detail, "w") as det:
        det.write("chrom\tpos\tref\talt\tgene\tconsequence\taf\n")
        for line in sys.stdin:
            f = line.rstrip("\n").split("\t")
            if len(f) < 5 or f[4] in (".", ""):
                continue
            af = first_af(f[5]) if (a.af_column and len(f) > 5) else None
            if a.af_column and af is not None and af >= a.af_max:
                continue
            seen = set()
            for entry in f[4].split(","):
                e = entry.split("|")
                if len(e) < 4:
                    continue
                gene, ann_terms = e[3], set(e[1].split("&"))
                if gene in genes and gene not in seen and ann_terms & terms:
                    seen.add(gene)
                    per_gene[gene] += 1
                    det.write(f"{f[0]}\t{f[1]}\t{f[2]}\t{f[3]}\t{gene}\t"
                              f"{'&'.join(sorted(ann_terms & terms))}\t{'NA' if af is None else af}\n")

    with open(a.out, "w") as out:
        out.write("set\tsubject\ttable\tcategory\tvalue\n")
        out.write(f"{a.set}\t{a.subject}\t__subject__\t__subject__\t1\n")
        for gene, n in sorted(per_gene.items()):
            out.write(f"{a.set}\t{a.subject}\trare_als\t{gene}\t{n}\n")


if __name__ == "__main__":
    main()
