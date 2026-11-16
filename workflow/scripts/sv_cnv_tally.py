#!/usr/bin/env python3
"""Rules 06/07: SV (--kind sv) or CNV (--kind cnv) tallies for one subject.

stdin: VCF body lines (`bcftools view -H`). Per record: class (SVTYPE, else symbolic ALT, else for CNVs
FORMAT/CN on autosomes: <2 LOSS, >2 GAIN), size (|SVLEN|, else END-POS), size bin, genic yes/no (interval
overlaps --genes BED, via `bedtools intersect -u`). Tables (long format): <kind>_type, <kind>_size_bin,
<kind>_genic. Breakends and unsized records -> size bin 'NA' (point interval for the gene test).
"""
import argparse
import subprocess
import sys
import tempfile
from collections import Counter

AUTOSOMES = {f"chr{i}" for i in range(1, 23)}


def parse_info(s):
    d = {}
    for kv in s.split(";"):
        k, _, v = kv.partition("=")
        d[k] = v
    return d


def size_bin(size, edges):
    if size is None:
        return "NA"
    if size < edges[0]:
        return f"<{edges[0]}"
    for lo, hi in zip(edges, edges[1:]):
        if size < hi:
            return f"{lo}-{hi - 1}"
    return f">={edges[-1]}"


def classify(chrom, alt, info, fmt, sample, kind):
    t = info.get("SVTYPE")
    if not t and alt.startswith("<"):
        t = alt.strip("<>").split(":")[0]
    if kind == "cnv" and (not t or t.upper() == "CNV") and chrom in AUTOSOMES and fmt and sample:
        keys, vals = fmt.split(":"), sample.split(":")
        if "CN" in keys and keys.index("CN") < len(vals):
            try:
                cn = float(vals[keys.index("CN")])
                return "LOSS" if cn < 2 else ("GAIN" if cn > 2 else "CNV_cn2")
            except ValueError:
                pass
    return (t or "OTHER").upper()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kind", choices=["sv", "cnv"], required=True)
    ap.add_argument("--set", required=True)
    ap.add_argument("--subject", required=True)
    ap.add_argument("--genes", required=True, help="gene BED (chr-prefixed GRCh38)")
    ap.add_argument("--bins", required=True, help="comma-separated ascending bin edges")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    edges = [int(x) for x in a.bins.split(",")]

    types, bins = Counter(), Counter()
    intervals = []
    for line in sys.stdin:
        f = line.rstrip("\n").split("\t")
        if len(f) < 8:
            continue
        chrom, pos, alt, info = f[0], int(f[1]), f[4], parse_info(f[7])
        fmt = f[8] if len(f) > 8 else ""
        sample = f[9] if len(f) > 9 else ""
        t = classify(chrom, alt, info, fmt, sample, a.kind)
        size = None
        if info.get("SVLEN") not in (None, "", "."):
            try:
                size = abs(int(float(info["SVLEN"].split(",")[0])))
            except ValueError:
                pass
        if size is None and "END" in info and t != "BND":
            try:
                size = abs(int(info["END"]) - pos)
            except ValueError:
                pass
        if t == "BND":
            size = None
        types[t] += 1
        bins[size_bin(size, edges)] += 1
        end = pos - 1 + (size if size else 1)
        intervals.append((chrom, pos - 1, max(end, pos)))

    genic = 0
    if intervals:
        with tempfile.NamedTemporaryFile("w", suffix=".bed") as tmp:
            for i, (c, s, e) in enumerate(intervals):
                tmp.write(f"{c}\t{s}\t{e}\t{i}\n")
            tmp.flush()
            res = subprocess.run(["bedtools", "intersect", "-u", "-a", tmp.name, "-b", a.genes],
                                 capture_output=True, text=True, check=True)
        genic = sum(1 for ln in res.stdout.splitlines() if ln)

    k = a.kind
    with open(a.out, "w") as out:
        out.write("set\tsubject\ttable\tcategory\tvalue\n")
        out.write(f"{a.set}\t{a.subject}\t__subject__\t__subject__\t1\n")
        for cat, n in sorted(types.items()):
            out.write(f"{a.set}\t{a.subject}\t{k}_type\t{cat}\t{n}\n")
        for cat, n in sorted(bins.items()):
            out.write(f"{a.set}\t{a.subject}\t{k}_size_bin\t{cat}\t{n}\n")
        out.write(f"{a.set}\t{a.subject}\t{k}_genic\tgenic\t{genic}\n")
        out.write(f"{a.set}\t{a.subject}\t{k}_genic\tnon_genic\t{len(intervals) - genic}\n")


if __name__ == "__main__":
    main()
