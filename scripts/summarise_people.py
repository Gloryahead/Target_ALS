#!/usr/bin/env python3
"""Person-level summary of check_target_variants.py --out-subject --with-ids output. COUNTS ONLY.

A person (subject_id) can appear in up to two sets. This script never merges calls; it only reports, per
person, whether they carry ALL targets (n_carried == n_targets), NONE (0) or SOME in each set, and then
how many people fall in each category. Output has no subject IDs.

Input: TSV with columns subject_id, set, group, n_targets, n_carried (extra columns ignored).
Usage: python scripts/summarise_people.py <per_subject.private.tsv> [--pairs setA:setB ...] [--out summary.tsv]
"""
import argparse
import csv
from collections import Counter, defaultdict


def status(k, n):
    return "all" if k == n else ("none" if k == 0 else "some")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("per_subject")
    ap.add_argument("--pairs", nargs="*", default=["psomagen_sr:psomagen_lr", "nygc_sr:psomagen_lr", "nygc_sr:psomagen_sr"])
    ap.add_argument("--out", default="")
    a = ap.parse_args()

    with open(a.per_subject, newline="") as fh:
        rows = list(csv.DictReader(fh, delimiter="\t"))
    if not rows or "subject_id" not in rows[0]:
        raise SystemExit("input must come from check_target_variants.py --out-subject ... --with-ids")

    per = defaultdict(dict)      # subject -> {set: status}
    groups = defaultdict(set)    # subject -> {groups}
    for r in rows:
        per[r["subject_id"]][r["set"]] = status(int(r["n_carried"]), int(r["n_targets"]))
        groups[r["subject_id"]].add(r["group"])

    lines = []
    out = lambda s="": lines.append(s)
    out(f"people (unique subjects): {len(per)}; subject-set rows: {len(rows)}")
    conflict = sum(1 for g in groups.values() if len(g) > 1)
    out(f"people with conflicting group labels across sets: {conflict}")

    out("\n== per person, any set: status by group (each person once) ==")
    c = Counter()
    for s, sets in per.items():
        sts = set(sets.values())
        overall = "all" if sts == {"all"} else ("none" if sts == {"none"} else ("mixed across sets" if len(sts) > 1 and "some" not in sts else "some"))
        c[(sorted(groups[s])[0] if len(groups[s]) == 1 else "conflict", overall)] += 1
    for (g, o), n in sorted(c.items()):
        out(f"{g}\t{o}\t{n}")

    out("\n== sets each person appears in ==")
    for combo, n in sorted(Counter("+".join(sorted(v)) for v in per.values()).items()):
        out(f"{combo}\t{n}")

    out("\n== agreement between two sets, people in BOTH (counts of people) ==")
    for pair in a.pairs:
        x, y = pair.split(":")
        both = [v for v in per.values() if x in v and y in v]
        if not both:
            out(f"{x} vs {y}: no shared people")
            continue
        t = Counter((v[x], v[y]) for v in both)
        out(f"{x} vs {y}: {len(both)} people shared; (status in {x}, status in {y}) -> n")
        for (sx, sy), n in sorted(t.items()):
            out(f"   {sx}\t{sy}\t{n}")

    text = "\n".join(lines)
    print(text)
    if a.out:
        open(a.out, "w").write(text + "\n")


if __name__ == "__main__":
    main()
