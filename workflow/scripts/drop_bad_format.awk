# Drop records whose FORMAT column repeats a key (e.g. "...:QS:FT:FT").
# NYGC Canvas VCFs contain a few such records; they have FILTER=FailedFT and a stub sample column
# (no genotype), and htslib/bcftools aborts on them. The set's `-f PASS` would remove them anyway.
# Header lines and all other records pass through unchanged; the number dropped is reported on stderr.
/^#/ { print; next }
{
  n = split($9, k, ":")
  dup = 0
  delete seen
  for (i = 1; i <= n; i++) { if (k[i] in seen) dup = 1; seen[k[i]] = 1 }
  if (dup) { dropped++; next }
  print
}
END { printf "drop_bad_format.awk: dropped %d records with a repeated FORMAT key\n", dropped + 0 > "/dev/stderr" }
