#!/usr/bin/env Rscript
# Rule 10 (report): figures + report_index.md from the AGGREGATE summaries/points only.
# Inputs: <root>/aggregate/<set>/<stage>.summary.tsv and .points.tsv (pseudonymised; no subject IDs).
# One figure per set x table family. Sets are never combined into one panel's data series;
# site is encoded as point shape / facet next to group. Descriptive only - no tests (about 5 controls).
suppressPackageStartupMessages({
  library(optparse)
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(stringr)
})

opt <- parse_args(OptionParser(option_list = list(
  make_option("--roots", type = "character", help = "space-separated stage=root pairs"),
  make_option("--outdir", type = "character")
)), positional_arguments = FALSE)

pairs <- str_split(str_trim(opt$roots), "\\s+")[[1]]
roots <- setNames(sub("^[^=]+=", "", pairs), sub("=.*$", "", pairs))
fig_dir <- file.path(opt$outdir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

grp_cols <- c(ALS = "#c0392b", Control = "#2c3e50")
theme_set(theme_bw(base_size = 11))

# all aggregate files that exist for each stage (sets and concordance pairs)
find_files <- function(stage, kind) {
  if (!(stage %in% names(roots))) return(character(0))
  root <- roots[[stage]]
  Sys.glob(file.path(root, "aggregate", "*", paste0(stage, ".", kind, ".tsv")))
}
read_all <- function(stage, kind) {
  fs <- find_files(stage, kind)
  if (length(fs) == 0) return(NULL)
  bind_rows(lapply(fs, read_tsv, show_col_types = FALSE))
}
save_fig <- function(p, name, w = 9, h = 5) {
  ggsave(file.path(fig_dir, paste0(name, ".png")), p, width = w, height = h, dpi = 200)
  name
}
index <- c("# Target ALS variant pipeline - report index",
           "", "Aggregate figures and tables only. Compare within a set; never across sets.",
           "Per-sample VCFs have no hom-ref calls: counts are carrier counts.", "")

# helper: per-subject points (jittered) with group colour, site shape, one facet per category
points_plot <- function(pts, tbl, title, facet_cat = TRUE) {
  d <- pts %>% filter(table == tbl)
  if (nrow(d) == 0) return(NULL)
  # box only for groups with >= 5 subjects (a box on 1-4 points is not meaningful); points always shown
  box_min <- 5
  p <- ggplot(d, aes(x = group, y = value, colour = group, shape = site)) +
    geom_boxplot(data = function(x) x %>% group_by(set, group, category) %>% filter(n() >= box_min) %>% ungroup(),
                 outlier.shape = NA, fill = NA, colour = "grey50") +
    geom_jitter(width = 0.15, size = 2) +
    scale_colour_manual(values = grp_cols, drop = FALSE) +
    labs(title = title, x = NULL, y = NULL,
         caption = paste0("Box shown only for groups with >= ", box_min, " subjects; points are individual subjects."))
  if (facet_cat) p <- p + facet_grid(category ~ set, scales = "free_y")
  p
}

# ── QC ───────────────────────────────────────────────────────────────
qc <- read_all("qc", "points")
if (!is.null(qc)) {
  p <- points_plot(qc, "qc", "Per-sample QC (standardised small variants)")
  if (!is.null(p)) index <- c(index, paste0("- QC: figures/", save_fig(p, "qc", 9, 12), ".png"))
  qs <- read_all("qc", "summary")
  write_tsv(qs, file.path(opt$outdir, "qc_summary.tsv"))
  index <- c(index, "- QC summary table: qc_summary.tsv")
}

# ── variant tables (types, consequences, spectrum) ───────────────────
vs <- read_all("variants", "summary")
if (!is.null(vs)) {
  write_tsv(vs, file.path(opt$outdir, "variants_summary.tsv"))
  frac_plot <- function(tbl, title, name, w = 10, h = 5) {
    d <- vs %>% filter(table == tbl) %>%
      group_by(set, group, site) %>% mutate(frac = mean / sum(mean)) %>% ungroup()
    if (nrow(d) == 0) return(NULL)
    p <- ggplot(d, aes(x = category, y = frac, fill = group)) +
      geom_col(position = "dodge") +
      facet_wrap(~ set + site, scales = "free_x") +
      scale_fill_manual(values = grp_cols) +
      labs(title = title, x = NULL, y = "category's share of the group's mean total per subject") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    save_fig(p, name, w, h)
  }
  for (spec in list(c("variant_type", "Variant types", "variant_types"),
                    c("substitution", "Six-class substitution spectrum", "substitution_spectrum"),
                    c("impact", "snpEff impact", "impact"),
                    c("consequence", "snpEff consequence (first ANN entry)", "consequence"))) {
    f <- frac_plot(spec[1], spec[2], spec[3], w = 12, h = 6)
    if (!is.null(f)) index <- c(index, paste0("- ", spec[2], ": figures/", f, ".png"))
  }
}

# ── rare protein-altering variants in the gene list: carriers per gene ──
rs <- read_all("rare", "summary")
if (!is.null(rs)) {
  write_tsv(rs, file.path(opt$outdir, "rare_als_gene_carriers.tsv"))
  # fraction of the group's subjects (groups differ a lot in size, so raw counts are not comparable)
  rs <- rs %>% mutate(frac_carriers = n_nonzero / n_subjects)
  write_tsv(rs, file.path(opt$outdir, "rare_als_gene_carriers.tsv"))
  p <- ggplot(rs, aes(x = reorder(category, -frac_carriers), y = frac_carriers, fill = group)) +
    geom_col(position = "dodge") +
    facet_wrap(~ set + site, scales = "free_x") +
    scale_fill_manual(values = grp_cols) +
    labs(title = "Fraction of subjects carrying a rare protein-altering variant, by gene",
         x = NULL, y = "fraction of the group's subjects",
         caption = "Group sizes differ (n_subjects is in rare_als_gene_carriers.tsv); descriptive only.") +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  index <- c(index, paste0("- Rare ALS-gene carriers: figures/", save_fig(p, "rare_als_gene_carriers", 12, 6),
                           ".png; rare_als_gene_carriers.tsv"))
}

# ── SV / CNV ─────────────────────────────────────────────────────────
for (kind in c("sv", "cnv")) {
  ks <- read_all(kind, "summary")
  if (is.null(ks)) next
  write_tsv(ks, file.path(opt$outdir, paste0(kind, "_summary.tsv")))
  for (tbl in c(paste0(kind, "_type"), paste0(kind, "_size_bin"))) {
    d <- ks %>% filter(table == tbl)
    if (nrow(d) == 0) next
    p <- ggplot(d, aes(x = category, y = mean, fill = group)) +
      geom_col(position = "dodge") +
      facet_wrap(~ set + site, scales = "free_x") +
      scale_fill_manual(values = grp_cols) +
      labs(title = paste(toupper(kind), "-", tbl), x = NULL, y = "mean count per subject") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    index <- c(index, paste0("- ", tbl, ": figures/", save_fig(p, tbl, 12, 6), ".png"))
  }
}

# ── repeat expansions ────────────────────────────────────────────────
rp <- read_all("repeats", "points")
if (!is.null(rp)) {
  d <- rp %>% filter(table == "repeat_max_count")
  if (nrow(d) > 0) {
    p <- ggplot(d, aes(x = group, y = value, colour = group, shape = site)) +
      geom_jitter(width = 0.15, size = 2) +
      scale_colour_manual(values = grp_cols) +
      facet_grid(category ~ set, scales = "free_y") +
      labs(title = "Longest called repeat allele per locus", x = NULL, y = "repeat units")
    index <- c(index, paste0("- Repeat alleles: figures/", save_fig(p, "repeat_max_count", 9, 6), ".png"))
  }
  rs2 <- read_all("repeats", "summary")
  write_tsv(rs2, file.path(opt$outdir, "repeats_summary.tsv"))
  index <- c(index, "- Repeat summary (n expanded per locus/group): repeats_summary.tsv")
}

# ── cross-site concordance ───────────────────────────────────────────
cc <- read_all("concordance", "points")
if (!is.null(cc)) {
  p <- ggplot(cc, aes(x = category, y = value, colour = group)) +
    geom_point(size = 2.5, position = position_jitter(width = 0.1)) +
    scale_colour_manual(values = grp_cols) +
    facet_wrap(~ set, scales = "free") +
    labs(title = "Same-subject concordance between two sets (site-level, exact match)",
         x = NULL, y = "variants") +
    theme(axis.text.x = element_text(angle = 30, hjust = 1))
  index <- c(index, paste0("- Concordance: figures/", save_fig(p, "concordance", 10, 5), ".png"))
  write_tsv(read_all("concordance", "summary"), file.path(opt$outdir, "concordance_summary.tsv"))
}

writeLines(index, file.path(opt$outdir, "report_index.md"))
