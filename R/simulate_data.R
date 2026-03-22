# =============================================================================
# simulate_data.R
# Generates synthetic ADaM-like (ADQS) datasets for all prototype studies.
#
# 3 therapeutic areas, 9 studies total, designed to demonstrate the full
# range of scenarios a real RWE platform would encounter:
#
#   DIGESTIVE HEALTH (5 studies)
#   ├── activia_eu_01    Strong positive signal       (EU, Adults)
#   ├── actimel_asia_02  Strong positive signal       (Asia, Adults)
#   ├── danone_elderly_03 Strong positive signal      (Elderly)
#   ├── activia_us_04    Moderate positive signal     (USA, Adults) — realistic
#   └── activia_japan_05 Near-null / non-significant  (Japan) — honest negative
#
#   BONE & JOINT HEALTH (2 studies)
#   ├── densia_eu_01     Moderate positive (higher=better endpoint)
#   └── densia_global_02 Moderate positive (joint flexibility)
#
#   IMMUNE SUPPORT (2 studies)
#   ├── actimel_immune_eu_01    Large positive (immune score)
#   └── actimel_immune_elder_02 Moderate positive (cold frequency reduction)
#
# Run once: source("R/simulate_data.R"); simulate_all_studies()
# =============================================================================

library(dplyr)
library(tidyr)

set.seed(42)

# =============================================================================
# Internal helper: generate one ADQS-like dataset
# =============================================================================
.make_adqs <- function(study_id,
                       paramcd,
                       param_label,
                       n_active,
                       n_placebo,
                       visits,
                       primary_avisitn,
                       baseline_mean,
                       baseline_sd,
                       active_effect,
                       placebo_effect,
                       effect_sd,
                       subgroup_var     = "SUBGRP",
                       higher_is_better = FALSE) {

  n_total <- n_active + n_placebo

  subjects <- tibble(
    USUBJID  = sprintf("%s-%03d", study_id, seq_len(n_total)),
    TRT01A   = c(rep("Active", n_active), rep("Placebo", n_placebo)),
    BASE_raw = rnorm(n_total, mean = baseline_mean, sd = baseline_sd)
  ) %>%
    mutate(
      BASE_raw       = round(pmax(1, BASE_raw), 1),
      !!subgroup_var := ifelse(
        BASE_raw <= median(BASE_raw), "Low Baseline", "High Baseline"
      )
    )

  visit_df <- tidyr::expand_grid(
    USUBJID = subjects$USUBJID,
    AVISITN = unname(visits)
  ) %>%
    mutate(AVISIT = names(visits)[match(AVISITN, visits)]) %>%
    left_join(subjects, by = "USUBJID")

  visit_df <- visit_df %>%
    mutate(
      noise          = rnorm(n(), 0, effect_sd * 0.5),
      visit_pct      = (AVISITN - min(AVISITN)) / (max(AVISITN) - min(AVISITN)),
      mean_chg       = ifelse(TRT01A == "Active",
                              active_effect  * visit_pct,
                              placebo_effect * visit_pct),
      subgroup_boost = ifelse(
        TRT01A == "Active" & !!sym(subgroup_var) == "High Baseline",
        active_effect * 0.3 * visit_pct, 0
      ),
      AVAL = round(BASE_raw + mean_chg + subgroup_boost + noise, 1),
      AVAL = pmax(0, AVAL),
      BASE = BASE_raw
    ) %>%
    select(-BASE_raw, -noise, -visit_pct, -mean_chg, -subgroup_boost)

  visit_df %>%
    mutate(
      CHG     = round(AVAL - BASE, 1),
      ABLFL   = ifelse(AVISITN == min(AVISITN), "Y", NA_character_),
      ANL01FL = ifelse(AVISITN == primary_avisitn, "Y", NA_character_),
      PARAMCD = paramcd,
      PARAM   = param_label,
      STUDYID = study_id,
      AVAL    = ifelse(!is.na(ABLFL), BASE, AVAL),
      CHG     = ifelse(!is.na(ABLFL), 0, CHG)
    ) %>%
    select(STUDYID, USUBJID, TRT01A, PARAMCD, PARAM,
           AVISITN, AVISIT, ABLFL, ANL01FL,
           BASE, AVAL, CHG, all_of(subgroup_var))
}

# Helper to write a study's ADQS to disk
.write_study <- function(adqs, out_dir) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(adqs, file.path(out_dir, "ADQS.csv"))
  message(sprintf("[simulate] %s written (%d rows)", basename(out_dir), nrow(adqs)))
  invisible(adqs)
}

# =============================================================================
# DIGESTIVE HEALTH
# =============================================================================

# --- activia_eu_01: Activia Probiotic, EU, Adults 18-65 ----------------------
# Scenario: STRONG positive signal. Primary study powering the evidence base.
.sim_activia_eu_01 <- function(base_dir) {
  visits <- c("Baseline" = 0, "Week 4" = 4, "Week 8" = 8)
  adqs <- bind_rows(
    .make_adqs("activia_eu_01", "GUT_COMFORT", "Gut Comfort Score (0-100)",
               40, 40, visits, 8, 62, 12, -18, -6, 8),
    .make_adqs("activia_eu_01", "BLOAT_SCR", "Bloating Score (0-10)",
               40, 40, visits, 8, 5.8, 1.5, -1.8, -0.5, 1.0)
  )
  .write_study(adqs, file.path(base_dir, "data/studies/activia_eu_01"))
}

# --- actimel_asia_02: Actimel Daily, Asia, Adults 18-65 ----------------------
# Scenario: STRONG positive signal, different instrument scale (0-10).
.sim_actimel_asia_02 <- function(base_dir) {
  visits <- c("Baseline" = 0, "Week 8" = 8, "Week 12" = 12)
  adqs <- bind_rows(
    .make_adqs("actimel_asia_02", "BLOAT_IDX", "Bloating Relief Index (0-10)",
               50, 50, visits, 12, 6.8, 1.4, -2.1, -0.6, 1.2),
    .make_adqs("actimel_asia_02", "BLOAT_SCR", "Bloating Score (0-10)",
               50, 50, visits, 12, 5.2, 1.8, -1.5, -0.4, 1.0)
  )
  .write_study(adqs, file.path(base_dir, "data/studies/actimel_asia_02"))
}

# --- danone_elderly_03: Actimel Senior, Adults 65+ ---------------------------
# Scenario: STRONG positive signal in elderly. Shorter study duration.
.sim_danone_elderly_03 <- function(base_dir) {
  visits <- c("Baseline" = 0, "Week 4" = 4, "Week 6" = 6)
  adqs <- .make_adqs("danone_elderly_03", "BOWEL_REG",
                     "Bowel Regularity Score (0-10)",
                     30, 30, visits, 6, 4.2, 1.1, -1.3, -0.3, 0.9)
  .write_study(adqs, file.path(base_dir, "data/studies/danone_elderly_03"))
}

# --- activia_us_04: Activia Probiotic, USA, Adults 18-65 ---------------------
# Scenario: MODERATE positive signal. Real-world effect size (~half of EU).
# Shows the system handles variation in effect size across geographies.
.sim_activia_us_04 <- function(base_dir) {
  visits <- c("Baseline" = 0, "Week 4" = 4, "Week 8" = 8)
  adqs <- .make_adqs("activia_us_04", "GUT_COMFORT",
                     "Gut Comfort Score (0-100)",
                     60, 60, visits, 8,
                     baseline_mean   = 58,
                     baseline_sd     = 14,
                     active_effect   = -9,    # moderate effect
                     placebo_effect  = -4,
                     effect_sd       = 10)
  .write_study(adqs, file.path(base_dir, "data/studies/activia_us_04"))
}

# --- activia_japan_05: Activia Light, Japan, Adults 18-65 --------------------
# Scenario: NEAR-NULL result (non-significant, p > 0.05).
# This is intentional — demonstrates the system is honest and credible,
# not just reporting cherry-picked positive studies.
.sim_activia_japan_05 <- function(base_dir) {
  visits <- c("Baseline" = 0, "Week 8" = 8, "Week 12" = 12)
  adqs <- .make_adqs("activia_japan_05", "GUT_COMFORT",
                     "Gut Comfort Score (0-100)",
                     45, 45, visits, 12,
                     baseline_mean   = 55,
                     baseline_sd     = 13,
                     active_effect   = -3.5,   # very small effect
                     placebo_effect  = -2.8,   # similar to active
                     effect_sd       = 11)     # high noise
  .write_study(adqs, file.path(base_dir, "data/studies/activia_japan_05"))
}

# =============================================================================
# BONE & JOINT HEALTH
# =============================================================================

# --- densia_eu_01: Densia, EU, Women 50+ -------------------------------------
# Scenario: MODERATE positive signal. HIGHER IS BETTER (bone density).
# Longer study (24 weeks). Different directionality than digestive endpoints.
.sim_densia_eu_01 <- function(base_dir) {
  visits <- c("Baseline" = 0, "Week 12" = 12, "Week 24" = 24)
  adqs <- .make_adqs("densia_eu_01", "BONE_DENS",
                     "Bone Density Score (T-score, standardized)",
                     40, 40, visits, 24,
                     baseline_mean   = 48,
                     baseline_sd     = 8,
                     active_effect   = +6,    # improvement = increase
                     placebo_effect  = +1.5,
                     effect_sd       = 5,
                     higher_is_better = TRUE)
  .write_study(adqs, file.path(base_dir, "data/studies/densia_eu_01"))
}

# --- densia_global_02: Densia Plus, Global, Adults 45+ -----------------------
# Scenario: MODERATE positive signal, joint flexibility endpoint.
.sim_densia_global_02 <- function(base_dir) {
  visits <- c("Baseline" = 0, "Week 8" = 8, "Week 12" = 12)
  adqs <- .make_adqs("densia_global_02", "JOINT_FLEX",
                     "Joint Flexibility Score (0-100)",
                     75, 75, visits, 12,
                     baseline_mean   = 42,
                     baseline_sd     = 10,
                     active_effect   = +8,   # higher is better
                     placebo_effect  = +2,
                     effect_sd       = 7,
                     higher_is_better = TRUE)
  .write_study(adqs, file.path(base_dir, "data/studies/densia_global_02"))
}

# =============================================================================
# IMMUNE SUPPORT
# =============================================================================

# --- actimel_immune_eu_01: Actimel, EU, Adults 18-65 -------------------------
# Scenario: LARGE positive signal. Immune response score (higher=better).
.sim_actimel_immune_eu_01 <- function(base_dir) {
  visits <- c("Baseline" = 0, "Week 4" = 4, "Week 8" = 8)
  adqs <- .make_adqs("actimel_immune_eu_01", "IMMUNE_SCR",
                     "Immune Response Score (0-100)",
                     50, 50, visits, 8,
                     baseline_mean   = 52,
                     baseline_sd     = 10,
                     active_effect   = +14,   # large improvement
                     placebo_effect  = +3,
                     effect_sd       = 7,
                     higher_is_better = TRUE)
  .write_study(adqs, file.path(base_dir, "data/studies/actimel_immune_eu_01"))
}

# --- actimel_immune_elder_02: Actimel Senior, EU, Adults 65+ -----------------
# Scenario: MODERATE signal. Cold episode frequency (lower=better).
# Subgroup effect stronger in High Baseline (most vulnerable) population.
.sim_actimel_immune_elder_02 <- function(base_dir) {
  visits <- c("Baseline" = 0, "Week 8" = 8, "Week 12" = 12)
  adqs <- .make_adqs("actimel_immune_elder_02", "COLD_FREQ",
                     "Cold Episode Frequency (per year)",
                     35, 35, visits, 12,
                     baseline_mean   = 3.8,
                     baseline_sd     = 1.2,
                     active_effect   = -1.1,   # fewer colds
                     placebo_effect  = -0.25,
                     effect_sd       = 0.9,
                     higher_is_better = FALSE)
  .write_study(adqs, file.path(base_dir, "data/studies/actimel_immune_elder_02"))
}

# =============================================================================
# Public entry point
# =============================================================================

#' Generate and save all synthetic study datasets
#'
#' @param base_dir Root directory of the project. Defaults to working directory.
simulate_all_studies <- function(base_dir = ".") {
  message("[simulate] Generating all studies...")

  # Digestive Health
  .sim_activia_eu_01(base_dir)
  .sim_actimel_asia_02(base_dir)
  .sim_danone_elderly_03(base_dir)
  .sim_activia_us_04(base_dir)
  .sim_activia_japan_05(base_dir)

  # Bone & Joint Health
  .sim_densia_eu_01(base_dir)
  .sim_densia_global_02(base_dir)

  # Immune Support
  .sim_actimel_immune_eu_01(base_dir)
  .sim_actimel_immune_elder_02(base_dir)

  message("[simulate] Done. 9 studies across 3 therapeutic areas.")
}
