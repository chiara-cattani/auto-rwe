# =============================================================================
# 03_endpoint_extraction.R  —  ENDPOINT EXTRACTION LAYER
#
# Responsibilities:
#   - Read metadata for (study_id, analysis_family)
#   - Load the correct dataset and variable
#   - Apply baseline / post-baseline / analysis-window rules
#   - Return a standardized subject-level dataset
#
# Public functions:
#   get_endpoint_data(study_id, analysis_family, endpoint_role, base_dir)
#   get_all_roles(study_id, analysis_family, base_dir)
# =============================================================================

library(dplyr)
library(tidyr)

# =============================================================================
# Main extraction function
# =============================================================================

#' Extract and standardize endpoint data for one study
#'
#' Uses metadata rules (baseline_rule, postbaseline_rule, analysis_window_rule)
#' to select the correct rows — no study-specific hardcoding here.
#'
#' @param study_id        Character. Study identifier.
#' @param analysis_family Character. e.g. "digestive_health".
#' @param endpoint_role   Character. e.g. "primary_symptom". If NULL, returns
#'                        primary role by default.
#' @param base_dir        Root directory of the project.
#'
#' @return Standardized tibble with columns:
#'   study_id, subject_id, treatment, endpoint, endpoint_role,
#'   baseline, value, change, timepoint, analysis_window, population, subgroup
get_endpoint_data <- function(study_id,
                               analysis_family,
                               endpoint_role = NULL,
                               base_dir      = ".") {

  # --- 1. Get metadata mapping row ----------------------------------------
  mapping <- get_endpoint_mapping(study_id, analysis_family, base_dir = base_dir)

  if (!is.null(endpoint_role)) {
    mapping <- mapping %>% filter(endpoint_role == !!endpoint_role)
    if (nrow(mapping) == 0) {
      stop(sprintf(
        "[extract] No mapping for study='%s', family='%s', role='%s'.",
        study_id, analysis_family, endpoint_role
      ))
    }
  }

  # Process each mapped endpoint role and bind results
  results <- lapply(seq_len(nrow(mapping)), function(i) {
    row <- mapping[i, ]
    .extract_one_endpoint(
      study_id        = study_id,
      mapping_row     = row,
      base_dir        = base_dir
    )
  })

  bind_rows(results)
}

#' Convenience: return data for all endpoint roles in a family
#'
#' @param study_id        Character.
#' @param analysis_family Character.
#' @param base_dir        Root directory.
#' @return Standardized tibble for all roles.
get_all_roles <- function(study_id, analysis_family, base_dir = ".") {
  get_endpoint_data(study_id, analysis_family,
                    endpoint_role = NULL, base_dir = base_dir)
}

# =============================================================================
# Internal: extract one endpoint from one mapping row
# =============================================================================
.extract_one_endpoint <- function(study_id, mapping_row, base_dir) {

  dataset_name        <- mapping_row$dataset_name
  variable_name       <- mapping_row$variable_name
  baseline_rule       <- mapping_row$baseline_rule
  postbaseline_rule   <- mapping_row$postbaseline_rule
  analysis_window_rule <- mapping_row$analysis_window_rule
  higher_is_better    <- mapping_row$higher_is_better
  ep_role             <- mapping_row$endpoint_role
  ep_family           <- mapping_row$analysis_family

  # --- 2. Load domain dataset ------------------------------------------------
  raw <- get_dataset(study_id, dataset_name, base_dir = base_dir)

  # --- 3. Filter for the specific parameter ----------------------------------
  if ("PARAMCD" %in% names(raw)) {
    param_data <- raw %>% filter(PARAMCD == variable_name)
  } else {
    # Fallback: look for a column matching the variable name directly
    if (!variable_name %in% names(raw)) {
      stop(sprintf(
        "[extract] Variable '%s' not found as PARAMCD or column in %s / %s.",
        variable_name, study_id, dataset_name
      ))
    }
    param_data <- raw
  }

  if (nrow(param_data) == 0) {
    warning(sprintf(
      "[extract] No rows for PARAMCD='%s' in %s / %s. Skipping.",
      variable_name, study_id, dataset_name
    ))
    return(NULL)
  }

  # --- 4. Identify baseline rows via baseline_rule ---------------------------
  # In standard ADaM, BASE is already computed and carried forward on every row.
  # We use it directly from post-baseline rows. The baseline_rule is used only
  # when BASE is missing (non-standard datasets).

  has_base_col <- "BASE" %in% names(param_data) &&
    !all(is.na(param_data$BASE))

  if (!has_base_col) {
    # Derive BASE from baseline rows
    base_rows <- apply_filter_rule(param_data, baseline_rule) %>%
      select(USUBJID, BASE = AVAL)

    param_data <- param_data %>%
      left_join(base_rows, by = "USUBJID")
  }

  # --- 5. Get post-baseline records at primary analysis window ---------------
  post_bl <- tryCatch(
    apply_filter_rule(param_data, postbaseline_rule),
    error = function(e) {
      # If ANL01FL column missing, fall back to non-baseline rows
      warning(sprintf(
        "[extract] postbaseline_rule '%s' failed for %s/%s: %s. Using non-baseline rows.",
        postbaseline_rule, study_id, variable_name, conditionMessage(e)
      ))
      param_data %>% filter(is.na(ABLFL))
    }
  )

  # Then filter to the primary analysis window
  primary_data <- apply_filter_rule(post_bl, analysis_window_rule)

  if (nrow(primary_data) == 0) {
    warning(sprintf(
      "[extract] No data after applying analysis_window_rule '%s' for %s/%s. Skipping.",
      analysis_window_rule, study_id, variable_name
    ))
    return(NULL)
  }

  # --- 6. Derive CHG if missing ----------------------------------------------
  if (!"CHG" %in% names(primary_data) || all(is.na(primary_data$CHG))) {
    primary_data <- primary_data %>%
      mutate(CHG = round(AVAL - BASE, 4))
  }

  # --- 7. Resolve analysis window label --------------------------------------
  aw_rule  <- .parse_rule(analysis_window_rule)
  aw_label <- resolve_analysis_window(
    study_id  = study_id,
    avisitn   = suppressWarnings(as.numeric(aw_rule$val)),
    base_dir  = base_dir
  )

  # --- 8. Detect subgroup column --------------------------------------------
  # Prefer SUBGRP; fall back to SEX, AGEGR1, or nothing
  subgroup_col <- .detect_subgroup_col(primary_data)

  # --- 9. Standardize output ------------------------------------------------
  out <- primary_data %>%
    transmute(
      study_id        = study_id,
      subject_id      = USUBJID,
      treatment       = TRT01A,
      endpoint        = variable_name,
      analysis_family = ep_family,
      endpoint_role   = ep_role,
      baseline        = BASE,
      value           = AVAL,
      change          = CHG,
      timepoint       = if ("AVISIT" %in% names(.)) AVISIT else NA_character_,
      avisitn         = if ("AVISITN" %in% names(.)) AVISITN else NA_real_,
      analysis_window = aw_label,
      higher_is_better = higher_is_better,
      population      = "Full Analysis Set",
      subgroup        = if (!is.null(subgroup_col))
                          .data[[subgroup_col]]
                        else NA_character_
    )

  return(out)
}

# Internal: find a subgroup column in the dataset
.detect_subgroup_col <- function(data) {
  candidates <- c("SUBGRP", "AGEGR1", "SEX", "RACE", "REGION")
  found <- intersect(candidates, names(data))
  if (length(found) > 0) return(found[[1]])
  return(NULL)
}
