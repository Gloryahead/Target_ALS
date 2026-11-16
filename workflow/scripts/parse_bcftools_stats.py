#!/usr/bin/env python3
"""Rule 02: turn `bcftools stats -s -` output into a long per-subject QC table.

Uses the SN (summary numbers), TSTV and PSC (per-sample counts) sections. Output columns:
set, subject, table, category, value  (+ a __subject__ row used by aggregate.py for denominators).
Ratios are NaN-safe (written as 'NA' when the denominator is 0).
"""
import argparse


def ratio(num, den):
    return "NA" if not den else f"{num / den:.4f}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stats", required=True)
    ap.add_argument("--set", required=True)
    ap.add_argument("--subject", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    sn, tstv, psc = {}, None, None
    with open(a.stats) as fh:
        for line in fh:
            if line.startswith("SN\t"):
                f = line.rstrip("\n").split("\t")
                sn[f[2].rstrip(":")] = float(f[3])
            elif line.startswith("TSTV\t"):
                f = line.rstrip("\n").split("\t")
                tstv = (float(f[2]), float(f[3]), f[4])          # ts, tv, ts/tv
            elif line.startswith("PSC\t") and psc is None:        # single-sample VCF: first PSC row
                psc = line.rstrip("\n").split("\t")

    n_snps = sn.get("number of SNPs", 0)
    n_indels = sn.get("number of indels", 0)
    rows = [
        ("n_records", sn.get("number of records", 0)),
        ("n_snps", n_snps),
        ("n_indels", n_indels),
        ("n_mnps", sn.get("number of MNPs", 0)),
        ("n_others", sn.get("number of others", 0)),
        ("snv_indel_ratio", ratio(n_snps, n_indels)),
    ]
    if tstv:
        rows.append(("ts_tv", tstv[2]))
    if psc:
        # PSC columns (0-based after splitting): 0 'PSC', 1 id, 2 sample, 3 nRefHom, 4 nNonRefHom,
        # 5 nHets, 6 nTransitions, 7 nTransversions, 8 nIndels, 9 avg depth, 10 nSingletons
        n_het, n_hom = float(psc[5]), float(psc[4])
        rows += [("n_het", n_het), ("n_nonref_hom", n_hom),
                 ("het_hom_ratio", ratio(n_het, n_hom)), ("n_singletons", float(psc[10]))]

    with open(a.out, "w") as out:
        out.write("set\tsubject\ttable\tcategory\tvalue\n")
        out.write(f"{a.set}\t{a.subject}\t__subject__\t__subject__\t1\n")
        for cat, val in rows:
            v = int(val) if isinstance(val, float) and val == int(val) else val
            out.write(f"{a.set}\t{a.subject}\tqc\t{cat}\t{v}\n")


if __name__ == "__main__":
    main()
