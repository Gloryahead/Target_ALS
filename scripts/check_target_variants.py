#!/usr/bin/env python3
"""Count carriers of a list of target variants, per set x group (counts only; never pooled across sets).

Reads the PRIVATE sample sheet and the standardised small-variant VCFs
(<root>/standardised/<set>/<subject>.small.vcf.gz, left-normalised, PASS/genotype-filtered, GRCh38).
A target matches a record only if CHROM, POS, REF and ALT are identical (targets must already be in
left-normalised VCF form; see the targets file below).

Targets file (TSV with header; extra columns ignored; may be git-ignored/private):
    label  chrom  pos  ref  alt
Output (TSV, group-level, no subject IDs):
    set group site label chrom pos ref alt n_subjects n_carriers n_het n_hom n_other_alt_at_pos

Per-sample VCFs hold no hom-ref calls, so only CARRIER counts are meaningful: n_subjects - n_carriers is
"not called as carrying the allele", NOT "homozygous reference". Comparisons are within a set.
Run inside the core environment (bcftools on PATH):   python scripts/check_target_variants.py ...
"""
import argparse
import csv
import os
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "workflow", "scripts"))
import sheetlib  # noqa: E402


def set_name(site, data_type):
    return f"{site}_{data_type}".lower()


def read_targets(path):
    with open(path, newline="") as fh:
        rows = [r for r in csv.DictReader((l for l in fh if l.strip() and not l.startswith("#")), delimiter="\t")]
    need = {"label", "chrom", "pos", "ref", "alt"}
    if not rows or not need <= set(rows[0]):
        sys.exit(f"targets file needs columns {sorted(need)}")
    return rows


def alt_count(gt):
    return sum(1 for a in gt.replace("|", "/").split("/") if a == "1")


def query(vcf, chrom, pos):
    out = subprocess.run(
        ["bcftools", "query", "-r", f"{chrom}:{pos}-{pos}", "-f", "%POS\t%REF\t%ALT[\t%GT]\n", vcf],
        capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError("bcftools query failed (VCF unreadable or not indexed)")
    return [l.split("\t") for l in out.stdout.splitlines() if l]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--standardised", required=True, help="<outdir>/standardised")
    ap.add_argument("--targets", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--out-combo", default="",
                    help="optional TSV: per set x group, how many subjects carry k of the targets (counts only)")
    a = ap.parse_args()

    targets = read_targets(a.targets)
    rows = sheetlib.read_rows(a.sheet)

    # counts[(set, group, site, label)] -> [n_subjects, n_carriers, n_het, n_hom, n_other_alt]
    counts = {}
    combo = {}      # (set, group, site) -> {k carried targets: n subjects}
    missing = 0
    for r in rows:
        sname = set_name(r["site"], r["data_type"])
        vcf = os.path.join(a.standardised, sname, f"{r['subject']}.small.vcf.gz")
        if not os.path.exists(vcf + ".tbi"):
            missing += 1
            continue
        carried = 0
        for t in targets:
            key = (sname, r["group"], r["site"], t["label"])
            c = counts.setdefault(key, [0, 0, 0, 0, 0])
            c[0] += 1
            hit = other = False
            het = hom = 0
            for pos, ref, alt, *gts in query(vcf, t["chrom"], t["pos"]):
                if pos != t["pos"]:
                    continue
                if ref == t["ref"] and alt == t["alt"]:
                    n = alt_count(gts[0]) if gts else 0
                    if n >= 1:
                        hit = True
                        hom, het = (1, 0) if n >= 2 else (0, 1)
                else:
                    other = True
            c[1] += int(hit); c[2] += het; c[3] += hom; c[4] += int(other and not hit)
            carried += int(hit)
        h = combo.setdefault((sname, r["group"], r["site"]), {})
        h[carried] = h.get(carried, 0) + 1

    tdict = {t["label"]: t for t in targets}
    with open(a.out, "w") as fh:
        fh.write("set\tgroup\tsite\tlabel\tchrom\tpos\tref\talt\tn_subjects\tn_carriers\tn_het\tn_hom\tn_other_alt_at_pos\n")
        for (sname, group, site, label), c in sorted(counts.items()):
            t = tdict[label]
            fh.write("\t".join([sname, group, site, label, t["chrom"], t["pos"], t["ref"], t["alt"]] + [str(x) for x in c]) + "\n")
    if a.out_combo:
        with open(a.out_combo, "w") as fh:
            fh.write(f"set\tgroup\tsite\tn_targets\tn_targets_carried\tn_subjects\n")
            for (sname, group, site), h in sorted(combo.items()):
                for k, n in sorted(h.items()):
                    fh.write(f"{sname}\t{group}\t{site}\t{len(targets)}\t{k}\t{n}\n")
        print(f"wrote {a.out_combo}")
    print(f"wrote {a.out}; subjects without a standardised VCF/index (skipped): {missing}")


if __name__ == "__main__":
    main()
