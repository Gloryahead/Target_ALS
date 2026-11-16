#!/usr/bin/env python3
"""Rule 08: repeat-expansion table for one subject from an ExpansionHunter-style VCF body.

stdin: VCF body lines (`bcftools view -H`). Loci are given as NAME:REPID:EXPANDED_MIN (REPID matched
case-insensitively against INFO/REPID). Allele repeat counts come from FORMAT/REPCN ('23/9', '12' for a
single allele, '.' for none; 'a-b' ranges use the upper bound). Tables: repeat_called, repeat_max_count,
repeat_expanded (category = locus name). --detail (participant-level, stays on xdisk) lists raw REPCN.
"""
import argparse
import re
import sys


def parse_counts(text):
    out = []
    for tok in re.split(r"[/|]", text):
        m = re.findall(r"\d+", tok)
        if m:
            out.append(int(m[-1]))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--set", required=True)
    ap.add_argument("--subject", required=True)
    ap.add_argument("--loci", nargs="+", required=True, help="NAME:REPID:EXPANDED_MIN ...")
    ap.add_argument("--out", required=True)
    ap.add_argument("--detail", required=True)
    a = ap.parse_args()

    loci = {}
    for spec in a.loci:
        name, repid, thr = spec.split(":")
        loci[repid.upper()] = (name, int(thr))

    found = {}
    with open(a.detail, "w") as det:
        det.write("locus\trepid\trepcn_raw\n")
        for line in sys.stdin:
            f = line.rstrip("\n").split("\t")
            if len(f) < 10:
                continue
            info = dict((kv.partition("=")[0], kv.partition("=")[2]) for kv in f[7].split(";"))
            repid = info.get("REPID", "").upper()
            if repid not in loci:
                continue
            keys, vals = f[8].split(":"), f[9].split(":")
            raw = vals[keys.index("REPCN")] if "REPCN" in keys and keys.index("REPCN") < len(vals) else "."
            name, _ = loci[repid]
            found[name] = parse_counts(raw)
            det.write(f"{name}\t{repid}\t{raw}\n")

    with open(a.out, "w") as out:
        out.write("set\tsubject\ttable\tcategory\tvalue\n")
        out.write(f"{a.set}\t{a.subject}\t__subject__\t__subject__\t1\n")
        for repid, (name, thr) in loci.items():
            if name not in found:
                continue
            counts = found[name]
            out.write(f"{a.set}\t{a.subject}\trepeat_called\t{name}\t1\n")
            if counts:
                mx = max(counts)
                out.write(f"{a.set}\t{a.subject}\trepeat_max_count\t{name}\t{mx}\n")
                out.write(f"{a.set}\t{a.subject}\trepeat_expanded\t{name}\t{int(mx >= thr)}\n")


if __name__ == "__main__":
    main()
