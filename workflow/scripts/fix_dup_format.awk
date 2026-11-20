# Drop repeated FORMAT keys (and the matching sample values), keeping the first occurrence.
# NYGC Canvas VCFs have a few records with FORMAT "...:QS:FT:FT"; htslib/bcftools aborts on those.
# Header lines and records without a repeated key pass through unchanged.
/^#/ { print; next }
{
  n = split($9, k, ":")
  dup = 0
  delete seen
  for (i = 1; i <= n; i++) { if (k[i] in seen) dup = 1; seen[k[i]] = 1 }
  if (dup) {
    delete seen
    fmt = ""; nk = 0
    for (i = 1; i <= n; i++) {
      if (k[i] in seen) { keep[i] = 0 }
      else { seen[k[i]] = 1; keep[i] = 1; fmt = fmt (nk++ ? ":" : "") k[i] }
    }
    $9 = fmt
    for (c = 10; c <= NF; c++) {
      m = split($c, v, ":")
      s = ""; nv = 0
      for (i = 1; i <= m && i <= n; i++) if (keep[i]) s = s (nv++ ? ":" : "") v[i]
      $c = s
    }
  }
  print
}
