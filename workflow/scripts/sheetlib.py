"""Sample-sheet helpers shared by the Snakefile and scripts. Standard library only.

Sample sheet (TSV, '#' comment lines allowed), one row per subject x set:
    subject  group  site  data_type  small_vcf  sv_vcf  cnv_vcf  repeats_vcf  eh_summary
A row's SET is fixed by (site, data_type) via config `sets`. Product columns not offered by that set
must be empty. Error messages never echo subject IDs or paths (they may end up in shared logs).
"""
import csv
import os

PRODUCT_COLUMN = {
    "small": "small_vcf",
    "sv": "sv_vcf",
    "cnv": "cnv_vcf",
    "repeats": "repeats_vcf",
    "repeat_table": "eh_summary",
}
REQUIRED = ["subject", "group", "site", "data_type"] + list(PRODUCT_COLUMN.values())


def read_rows(path):
    if not os.path.exists(path):
        raise FileNotFoundError(
            "Sample sheet not found (config 'samples'). Build it on Puma with "
            "scripts/build_sample_sheet.py - it is private and git-ignored."
        )
    with open(path, newline="") as fh:
        lines = [ln for ln in fh if ln.strip() and not ln.lstrip().startswith("#")]
    rows = list(csv.DictReader(lines, delimiter="\t"))
    if not rows:
        raise ValueError("Sample sheet has no data rows.")
    missing = [c for c in REQUIRED if c not in rows[0]]
    if missing:
        raise ValueError(f"Sample sheet is missing columns: {missing}")
    return [{k: (v or "").strip() for k, v in r.items()} for r in rows]


def set_lookup(sets):
    """(site.upper(), data_type.upper()) -> set name."""
    out = {}
    for name, s in sets.items():
        key = (s["site"].upper(), s["data_type"].upper())
        if key in out:
            raise ValueError("Two sets share the same (site, data_type).")
        out[key] = name
    return out


def load_sheet(path, sets):
    """Return {set: {subject: row}} for every set in config (empty dict if no subjects).

    Raises ValueError (without IDs) on: unknown (site, data_type), duplicate subject within a set,
    group not allowed for the set (e.g. a control in psomagen_lr), missing small_vcf, or a product
    column filled for a product the set does not have.
    """
    lookup = set_lookup(sets)
    units = {name: {} for name in sets}
    for i, r in enumerate(read_rows(path), start=2):
        key = (r["site"].upper(), r["data_type"].upper())
        if key not in lookup:
            raise ValueError(f"Sample sheet line {i}: (site, data_type) matches no configured set.")
        name = lookup[key]
        cfg = sets[name]
        if not r["subject"]:
            raise ValueError(f"Sample sheet line {i}: empty subject.")
        if r["group"] not in cfg["groups"]:
            raise ValueError(
                f"Sample sheet line {i}: group '{r['group']}' not allowed in set {name} "
                f"(allowed: {cfg['groups']})."
            )
        if r["subject"] in units[name]:
            raise ValueError(f"Sample sheet line {i}: duplicate subject within set {name}.")
        if not r[PRODUCT_COLUMN["small"]]:
            raise ValueError(f"Sample sheet line {i}: small_vcf is empty (exclude such subjects).")
        for prod, col in PRODUCT_COLUMN.items():
            if r[col] and prod not in cfg["products"]:
                raise ValueError(f"Sample sheet line {i}: {col} filled but set {name} has no '{prod}' product.")
        units[name][r["subject"]] = r
    return units


def subjects_with(units, set_name, product):
    col = PRODUCT_COLUMN[product]
    return sorted(s for s, r in units[set_name].items() if r[col])
