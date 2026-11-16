#!/usr/bin/env python3
"""Rule 00: validate the private sample sheet; write COUNTS ONLY (no IDs, no paths)."""
import argparse
import json
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sheetlib  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--sets-json", required=True, help="JSON: {set: {site, data_type, groups, products}}")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    sets = json.loads(a.sets_json)
    units = sheetlib.load_sheet(a.sheet, sets)   # raises (ID-free message) on structural problems

    lines, n_missing = [], 0
    for name in sets:
        rows = list(units[name].values())
        by_group = Counter(r["group"] for r in rows)
        lines.append(f"set {name}: {len(rows)} subjects; by group: " +
                     ", ".join(f"{g}={by_group.get(g, 0)}" for g in sets[name]["groups"]))
        for prod, col in sheetlib.PRODUCT_COLUMN.items():
            have = [r[col] for r in rows if r[col]]
            missing = sum(1 for p in have if not os.path.exists(p))
            n_missing += missing
            if prod in sets[name]["products"] or have:
                lines.append(f"  product {prod}: {len(have)} files listed, {missing} missing on disk")
    lines.append(f"TOTAL missing files: {n_missing}")

    if n_missing:
        sys.stderr.write("\n".join(lines) + "\nERROR: sample sheet points at missing files.\n")
        sys.exit(1)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w") as fh:
        fh.write("\n".join(lines) + "\nOK\n")


if __name__ == "__main__":
    main()
