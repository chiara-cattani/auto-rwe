# =============================================================================
# 05_aggregation.R  —  AGGREGATION LAYER
#
# Loops across studies, runs extraction + analysis, assembles the
# standardized "evidence object".
#
# Public functions:
#   run_across_studies(analysis_family, study_list, base_dir)
#   run_subgroup_analysis(analysis_family, study_list, subgroup_var, base_dir)
# =============================================================================

library(dplyr)
library(purrr)

# =============================================================================
# run_across_studies()
# =============================================================================

#' Run the full analysis pipeline across multiple studies
#'
#' For each study:
#'   1. get_endpoint_data()   — extract standardized subject-level data
#'   2. detect_signal()       — effect size, direction, significance
#'   3. analyze_subgroup()    — subgroup summary
#' Then joins study catalog metadata and assembles the evidence object.
#'
#' @param analysis_family  Character. e.g. "digestive_health".
#' @param study_list       Character vector of study IDs. If NULL, auto-detects
#'                         from metadata.
#' @param endpoint_role    Character. If NULL, uses primary_symptom by default.
#' @param base_dir         Root directory of the project.
#' @param verbose          Print progress messages.
#'
#' @return Evidence object: tibble with one row per study, columns:
#'   study_id, product, population, design_type,
#'   endpoint, analysis_window,
#'   n_active, n_placebo,
#'   mean_change_active, mean_change_placebo,
#'   treatment_diff, ci_lower, ci_upper, p_value,
#'   cohens_d, direction, significance, strength_label,
#'   subgroup_summary, confidence_flag
run_across_studies <- function(analysis_family,
                                study_list    = NULL,
                                endpoint_role = "primary_symptom",
                                base_dir      = ".",
                                verbose       = TRUE) {

  load_metadata(base_dir = base_dir)

  # Auto-detect studies if not supplied
  if (is.null(study_list)) {
    study_list <- get_studies_for_family(analysis_family, base_dir = base_dir)
    if (verbose) message(sprintf(
      "[aggregation] Auto-detected %d studies for family '%s': %s",
      length(study_list), analysis_family, paste(study_list, collapse = ", ")
    ))
  }

  if (length(study_list) == 0) {
    stop(sprintf("[aggregation] No studies found for family '%s'.", analysis_family))
  }

  # Process each study
  evidence_rows <- purrr::map(study_list, function(sid) {
    if (verbose) message(sprintf("[aggregation] Processing: %s ...", sid))

    result <- tryCatch(
      .process_one_study(
        study_id        = sid,
        analysis_family = analysis_family,
        endpoint_role   = endpoint_role,
        base_dir        = base_dir
      ),
      error = function(e) {
        warning(sprintf(
          "[aggregation] Failed for study '%s': %s", sid, conditionMessage(e)
        ))
        return(NULL)
      }
    )
    return(result)
  })

  evidence_rows <- purrr::compact(evidence_rows)  # drop NULLs

  if (length(evidence_rows) == 0) {
    stop("[aggregation] All studies failed. Evidence object is empty.")
  }

  evidence <- bind_rows(evidence_rows)

  # Join study catalog metadata
  catalog <- .meta_cache$study_catalog %>%
    select(study_id, product, population, design_type)

  evidence <- evidence %>%
    left_join(catalog, by = "study_id") %>%
    relocate(study_id, product, population, design_type) %>%
    arrange(study_id)

  # Apply confidence flag
  evidence <- evidence %>%
    mutate(confidence_flag = .compute_confidence_flag(
      n_active, n_placebo, p_value, cohens_d
    ))

  if (verbose) message(sprintf(
    "[aggregation] Evidence object assembled: %d studies, %d endpoints.",
    length(unique(evidence$study_id)), nrow(evidence)
  ))

  class(evidence) <- c("rwe_evidence", class(evidence))
  return(evidence)
}

# =============================================================================
# run_subgroup_analysis()
# =============================================================================

#' Subgroup analysis across studies
#'
#' @param analysis_family  Character. Analysis family name.
#' @param study_list       Character vector of study IDs.
#' @param subgroup_var     Character. Column to stratify on.
#' @param endpoint_role    Character. Endpoint role to analyze.
#' @param base_dir         Root directory.
#'
#' @return Tibble with one row per (study_id, subgroup_level).
run_subgroup_analysis <- function(analysis_family,
                                   study_list    = NULL,
                                   subgroup_var  = "subgroup",
                                   endpoint_role = "primary_symptom",
                                   base_dir      = ".") {

  load_metadata(base_dir = base_dir)

  if (is.null(study_list)) {
    study_list <- get_studies_for_family(analysis_family, base_dir = base_dir)
  }

  results <- purrr::map(study_list, function(sid) {
    tryCatch({
      ep_data <- get_endpoint_data(
        study_id        = sid,
        analysis_family = analysis_family,
        endpoint_role   = endpoint_role,
        base_dir        = base_dir
      )
      sub_result <- analyze_subgroup(ep_data, subgroup_var = subgroup_var)
      sub_result
    }, error = function(e) {
      warning(sprintf("[subgroup] Failed for '%s': %s", sid, conditionMessage(e)))
      NULL
    })
  })

  catalog <- .meta_cache$study_catalog %>%
    select(study_id, product, population)

  bind_rows(purrr::compact(results)) %>%
    left_join(catalog, by = "study_id") %>%
    relocate(study_id, product, population) %>%
    arrange(study_id, subgroup_level)
}

# =============================================================================
# Internal helpers
# =============================================================================

.process_one_study <- function(study_id, analysis_family,
                                endpoint_role, base_dir) {

  # 1. Extract endpoint data
  ep_data <- get_endpoint_data(
    study_id        = study_id,
    analysis_family = analysis_family,
    endpoint_role   = endpoint_role,
    base_dir        = base_dir
  )

  # 2. Signal detection (includes treatment comparison)
  signal <- detect_signal(ep_data)

  # 3. Subgroup summary (compact text)
  sub_result <- tryCatch(
    analyze_subgroup(ep_data, subgroup_var = "subgroup"),
    error = function(e) NULL
  )
  subgroup_summary <- .summarise_subgroups(sub_result)

  # 4. Assemble row
  signal %>%
    mutate(subgroup_summary = subgroup_summary)
}

# Compact text summary of subgroup effects
.summarise_subgroups <- function(sub_result) {

  if (is.null(sub_result) || nrow(sub_result) == 0) return(NA_character_)

  non_overall <- sub_result %>% filter(subgroup_level != "Overall")

  if (nrow(non_overall) == 0) return("No subgroup data")

  parts <- non_overall %>%
    mutate(
      sig_label = dplyr::case_when(
        p_value <= 0.001 ~ "***",
        p_value <= 0.01  ~ "**",
        p_value <= 0.05  ~ "*",
        p_value <= 0.10  ~ ".",
        TRUE             ~ "ns"
      ),
      txt = sprintf(
        "%s: diff=%.2f (p=%.3f, %s)",
        subgroup_level, treatment_diff, p_value, sig_label
      )
    ) %>%
    pull(txt)

  paste(parts, collapse = " | ")
}

# Flag confidence level based on sample size and evidence quality
.compute_confidence_flag <- function(n_active, n_placebo, p_value, cohens_d) {
  dplyr::case_when(
    n_active >= 30 & n_placebo >= 30 & p_value <= 0.05 & cohens_d >= 0.3 ~ "high",
    n_active >= 15 & n_placebo >= 15 & p_value <= 0.10                   ~ "moderate",
    TRUE                                                                   ~ "low"
  )
}
