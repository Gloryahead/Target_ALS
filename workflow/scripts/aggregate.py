#!/usr/bin/env python3
"""Rule 10 (aggregate): collapse per-subject long tables into group-level summaries for ONE set.

Inputs: per-subject TSVs with columns set, subject, table, category, value. Every table contains a
`__subject__` row per subject (the denominator). A category absent for a subject counts as 0 - valid for
the carrier-count tables produced here (per-sample VCFs have no hom-ref calls). 'NA' values are skipped.

Outputs (no subject IDs):
  --summary  set, group, site, table, category, n_subjects, n_nonzero, sum, mean, median, min, max
  --points   pseudonym (<set>-<group>-NN), set, group, site, table, category, value
Sets are never combined: one call = one set (or one cross-set concordance pair).
"""
import argparse
import os
import statistics
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sheetlib  # noqa: E402


def fmt(x):
    return f"{x:.6g}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--set", required=True)
    ap.add_argument("--site", required=True, help="site label; 'cross-site' for concordance pairs")
    ap.add_argument("--data-type", default="")
    ap.add_argument("--stage", required=True)
    ap.add_argument("--summary", required=True)
    ap.add_argument("--points", required=True)
    ap.add_argument("tables", nargs="+")
    a = ap.parse_args()

    # subject -> group (private sheet; used here only, never written out with IDs)
    group_of = {}
    for r in sheetlib.read_rows(a.sheet):
        if a.site != "cross-site" and (r["site"] != a.site or r["data_type"].upper() != a.data_type.upper()):
            continue
        group_of.setdefault(r["subject"], r["group"])

    values = defaultdict(dict)      # (table, category) -> {subject: value}
    subjects = set()
    for path in a.tables:
        with open(path) as fh:
            next(fh)
            for line in fh:
                _, subj, table, cat, val = line.rstrip("\n").split("\t")
                if table == "__subject__":
                    subjects.add(subj)
                else:
                    values[(table, cat)][subj] = val
    unknown = [s for s in subjects if s not in group_of]
    if unknown:
        sys.exit(f"ERROR: {len(unknown)} subject(s) in tables not found in the sample sheet for this set.")

    by_group = defaultdict(list)
    for s in sorted(subjects):
        by_group[group_of[s]].append(s)
    pseudo = {s: f"{a.set}-{g}-{i:02d}" for g, subs in by_group.items() for i, s in enumerate(subs, 1)}

    with open(a.summary, "w") as sm, open(a.points, "w") as pt:
        sm.write("set\tgroup\tsite\ttable\tcategory\tn_subjects\tn_nonzero\tsum\tmean\tmedian\tmin\tmax\n")
        pt.write("pseudonym\tset\tgroup\tsite\ttable\tcategory\tvalue\n")
        for (table, cat) in sorted(values):
            for g, subs in sorted(by_group.items()):
                vec = []
                for s in subs:
                    raw = values[(table, cat)].get(s, "0")
                    if raw == "NA":
                        continue
                    v = float(raw)
                    vec.append(v)
                    pt.write(f"{pseudo[s]}\t{a.set}\t{g}\t{a.site}\t{table}\t{cat}\t{fmt(v)}\n")
                if not vec:
                    continue
                sm.write("\t".join([a.set, g, a.site, table, cat, str(len(subs)),
                                    str(sum(1 for v in vec if v != 0)), fmt(sum(vec)),
                                    fmt(sum(vec) / len(vec)), fmt(statistics.median(vec)),
                                    fmt(min(vec)), fmt(max(vec))]) + "\n")


if __name__ == "__main__":
    main()
