#!/usr/bin/env python3
"""Build the PRIVATE sample sheet (config/samples.private.tsv) from the downloaded folders.

Run on Puma by the user (slurm/03_build_sample_sheet.slurm). It walks each set's source folders, matches
files by the globs in config/config.yaml, takes the subject ID from the FILE NAME with
sample_sheet.subject_regex, and writes one row per subject x set.

PRIVACY: stdout/stderr carry COUNTS ONLY (never IDs or paths), so the job log is safe to share.
Subjects with no small-variant VCF (e.g. a CRAM-only subject) are excluded and counted.
Subjects with more than one file for the same product are excluded and counted (resolve by hand).
"""
import argparse
import csv
import fnmatch
import os
import re
import sys
from collections import Counter, defaultdict

import yaml

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "workflow", "scripts"))
import sheetlib  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default="config/config.yaml")
    ap.add_argument("--out", default="config/samples.private.tsv")
    a = ap.parse_args()

    cfg = yaml.safe_load(open(a.config))
    root = cfg["sample_sheet"]["vcf_root"]
    rx = re.compile(cfg["sample_sheet"]["subject_regex"])

    rows, report = [], []
    for set_name, s in cfg["sets"].items():
        found = defaultdict(lambda: defaultdict(list))      # subject -> product -> [paths]
        group_of = {}
        n_nomatch = 0
        for src in s["sources"]:
            d = os.path.join(root, src["dir"])
            if not os.path.isdir(d):
                report.append(f"{set_name}: source folder {src['dir']} not found")
                continue
            for fn in sorted(os.listdir(d)):
                for prod, spec in s["products"].items():
                    if not fnmatch.fnmatch(fn, spec["glob"]):
                        continue
                    if spec.get("exclude_glob") and fnmatch.fnmatch(fn, spec["exclude_glob"]):
                        continue
                    m = rx.search(fn)
                    if not m:
                        n_nomatch += 1
                        continue
                    found[m.group(1)][prod].append(os.path.join(d, fn))
                    group_of[m.group(1)] = src["group"]
        n_ok = n_nosmall = n_dup = 0
        prod_counts = Counter()
        for subj, prods in sorted(found.items()):
            if not prods.get("small"):
                n_nosmall += 1
                continue
            if any(len(v) > 1 for v in prods.values()):
                n_dup += 1
                continue
            row = {"subject": subj, "group": group_of[subj], "site": s["site"], "data_type": s["data_type"]}
            for prod, col in sheetlib.PRODUCT_COLUMN.items():
                row[col] = prods[prod][0] if prods.get(prod) else ""
                prod_counts[prod] += 1 if row[col] else 0
            rows.append(row)
            n_ok += 1
        report.append(f"{set_name}: {n_ok} subjects written; {n_nosmall} excluded (no small VCF); "
                      f"{n_dup} excluded (duplicate files); {n_nomatch} files without a subject-regex match; "
                      f"products: " + ", ".join(f"{p}={prod_counts[p]}" for p in s["products"]))

    cols = ["subject", "group", "site", "data_type"] + list(sheetlib.PRODUCT_COLUMN.values())
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, delimiter="\t")
        w.writeheader()
        w.writerows(rows)
    print("\n".join(report))
    print(f"wrote {len(rows)} rows (private file, git-ignored)")


if __name__ == "__main__":
    main()
