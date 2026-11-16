#!/usr/bin/env python3
"""Rule 04: variant-type, consequence, impact and six-class substitution tables for one subject.

stdin: `bcftools query -f '%REF\\t%ALT\\t%INFO/ANN\\n'` from the uniformly snpEff-annotated VCF
(one ALT per record after `bcftools norm -m -any`). The FIRST ANN entry is used (snpEff orders entries
by its own impact ranking). Output: long table set, subject, table, category, value.
"""
import argparse
import sys
from collections import Counter

COMP = str.maketrans("ACGT", "TGCA")
SIX = {"C>A", "C>G", "C>T", "T>A", "T>C", "T>G"}


def variant_type(ref, alt):
    if alt.startswith("<") or "[" in alt or "]" in alt or alt in ("*", "."):
        return "other"
    if len(ref) == 1 and len(alt) == 1:
        return "SNV"
    if len(ref) == len(alt):
        return "MNV"
    if len(ref) < len(alt):
        return "INS" if alt.startswith(ref) else "complex"
    return "DEL" if ref.startswith(alt) else "complex"


def substitution(ref, alt):
    ref, alt = ref.upper(), alt.upper()
    if ref in ("A", "G"):                       # collapse to pyrimidine reference strand
        ref, alt = ref.translate(COMP), alt.translate(COMP)
    key = f"{ref}>{alt}"
    return key if key in SIX else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--set", required=True)
    ap.add_argument("--subject", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    vt, cons, imp, sub = Counter(), Counter(), Counter(), Counter()
    for line in sys.stdin:
        f = line.rstrip("\n").split("\t")
        if len(f) < 2:
            continue
        ref, alt = f[0], f[1]
        ann = f[2] if len(f) > 2 else "."
        t = variant_type(ref, alt)
        vt[t] += 1
        if t == "SNV":
            s = substitution(ref, alt)
            if s:
                sub[s] += 1
        if ann in (".", ""):
            cons["no_annotation"] += 1
            imp["no_annotation"] += 1
        else:
            first = ann.split(",")[0].split("|")
            cons[first[1].split("&")[0] if len(first) > 1 and first[1] else "no_annotation"] += 1
            imp[first[2] if len(first) > 2 and first[2] else "no_annotation"] += 1

    with open(a.out, "w") as out:
        out.write("set\tsubject\ttable\tcategory\tvalue\n")
        out.write(f"{a.set}\t{a.subject}\t__subject__\t__subject__\t1\n")
        for table, counter in (("variant_type", vt), ("consequence", cons),
                               ("impact", imp), ("substitution", sub)):
            for cat, n in sorted(counter.items()):
                out.write(f"{a.set}\t{a.subject}\t{table}\t{cat}\t{n}\n")


if __name__ == "__main__":
    main()
