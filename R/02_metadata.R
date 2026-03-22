# =============================================================================
# 02_metadata.R  —  METADATA / MAPPING LAYER
#
# Responsibilities:
#   - Load and cache the three metadata tables
#   - Provide lookup helpers used by the extraction layer
#   - Implement a safe rule parser (no eval/parse on user strings)
#
# Public functions:
#   load_metadata(base_dir)
#   get_study_info(study_id)
#   get_endpoint_mapping(study_id, analysis_family)
#   get_visit_mapping(study_id)
#   apply_filter_rule(data, rule_str)
#   resolve_analysis_window(study_id, avisitn)
# =============================================================================

library(dplyr)
library(readr)
library(stringr)

# Internal metadata cache
.meta_cache <- new.env(parent = emptyenv())

# =============================================================================
# Load / cache metadata tables
# =============================================================================

#' Load all three metadata tables into cache
#'
#' @param base_dir Root directory of the project.
#' @param refresh  Force reload from disk.
#' @return Invisibly returns a named list of the three tables.
load_metadata <- function(base_dir = ".", refresh = FALSE) {

  if (!refresh && exists("loaded", envir = .meta_cache)) {
    return(invisible(list(
      study_catalog    = .meta_cache$study_catalog,
      endpoint_mapping = .meta_cache$endpoint_mapping,
      visit_mapping    = .meta_cache$visit_mapping
    )))
  }

  meta_dir <- file.path(base_dir, "data", "metadata")

  .meta_cache$study_catalog <- readr::read_csv(
    file.path(meta_dir, "study_catalog.csv"),
    show_col_types = FALSE
  )
  .meta_cache$endpoint_mapping <- readr::read_csv(
    file.path(meta_dir, "endpoint_mapping.csv"),
    show_col_types = FALSE
  )
  .meta_cache$visit_mapping <- readr::read_csv(
    file.path(meta_dir, "visit_mapping.csv"),
    show_col_types = FALSE
  )
  .meta_cache$loaded    <- TRUE
  .meta_cache$base_dir  <- base_dir

  message(sprintf(
    "[metadata] Loaded: %d studies | %d endpoint mappings | %d visit mappings",
    nrow(.meta_cache$study_catalog),
    nrow(.meta_cache$endpoint_mapping),
    nrow(.meta_cache$visit_mapping)
  ))

  invisible(list(
    study_catalog    = .meta_cache$study_catalog,
    endpoint_mapping = .meta_cache$endpoint_mapping,
    visit_mapping    = .meta_cache$visit_mapping
  ))
}

# Internal helper: ensure metadata is loaded
.ensure_metadata <- function(base_dir = ".") {
  if (!exists("loaded", envir = .meta_cache)) {
    load_metadata(base_dir = base_dir)
  }
}

# =============================================================================
# Lookup helpers
# =============================================================================

#' Get study-level attributes from the catalog
#'
#' @param study_id  Character study identifier.
#' @param base_dir  Root directory.
#' @return Single-row tibble from study_catalog.
get_study_info <- function(study_id, base_dir = ".") {

  .ensure_metadata(base_dir)

  row <- .meta_cache$study_catalog %>%
    filter(study_id == !!study_id)

  if (nrow(row) == 0) {
    stop(sprintf(
      "[metadata] study_id '%s' not found in study_catalog.", study_id
    ))
  }
  return(row)
}

#' Get all endpoint mapping rows for a study / analysis family
#'
#' @param study_id        Character study identifier.
#' @param analysis_family Character family name (e.g. "digestive_health").
#' @param base_dir        Root directory.
#' @return Tibble of matching rows from endpoint_mapping.
get_endpoint_mapping <- function(study_id, analysis_family, base_dir = ".") {

  .ensure_metadata(base_dir)

  rows <- .meta_cache$endpoint_mapping %>%
    filter(
      study_id        == !!study_id,
      analysis_family == !!analysis_family
    )

  if (nrow(rows) == 0) {
    stop(sprintf(
      "[metadata] No endpoint mapping for study='%s', family='%s'.",
      study_id, analysis_family
    ))
  }
  return(rows)
}

#' Get visit mapping for a study
#'
#' @param study_id  Character study identifier.
#' @param base_dir  Root directory.
#' @return Tibble of visit mappings for the study.
get_visit_mapping <- function(study_id, base_dir = ".") {

  .ensure_metadata(base_dir)

  .meta_cache$visit_mapping %>%
    filter(study_id == !!study_id)
}

#' List all studies that have mappings for a given analysis family
#'
#' @param analysis_family  Character (e.g. "digestive_health").
#' @param base_dir         Root directory.
#' @return Character vector of study_ids.
get_studies_for_family <- function(analysis_family, base_dir = ".") {

  .ensure_metadata(base_dir)

  .meta_cache$endpoint_mapping %>%
    filter(analysis_family == !!analysis_family) %>%
    pull(study_id) %>%
    unique()
}

# =============================================================================
# Rule parser — safe, no eval()
# =============================================================================
#
# Rules are stored in metadata as simple "COLNAME=VALUE" strings.
# Examples:
#   "ABLFL=Y"     -> filter(data, ABLFL == "Y")
#   "ANL01FL=Y"   -> filter(data, ANL01FL == "Y")
#   "AVISITN=8"   -> filter(data, AVISITN == 8)
#
# No arbitrary R code is executed.

.parse_rule <- function(rule_str) {
  parts <- str_split_fixed(str_trim(rule_str), "=", n = 2)
  col   <- str_trim(parts[1])
  val   <- str_trim(parts[2])
  list(col = col, val = val)
}

#' Apply a filter rule string to a data frame
#'
#' @param data      A tibble / data frame.
#' @param rule_str  Rule string like "ABLFL=Y" or "AVISITN=8".
#' @return Filtered tibble.
apply_filter_rule <- function(data, rule_str) {

  rule <- .parse_rule(rule_str)
  col  <- rule$col
  val  <- rule$val

  if (!col %in% names(data)) {
    stop(sprintf(
      "[metadata] Rule references column '%s' which does not exist in data.", col
    ))
  }

  col_data <- data[[col]]

  if (is.numeric(col_data)) {
    num_val <- suppressWarnings(as.numeric(val))
    if (is.na(num_val)) {
      stop(sprintf(
        "[metadata] Column '%s' is numeric but rule value '%s' is not.", col, val
      ))
    }
    return(data[!is.na(col_data) & col_data == num_val, ])
  } else {
    return(data[!is.na(col_data) & col_data == val, ])
  }
}

#' Map a numeric visit (AVISITN) to an analysis window label
#'
#' @param study_id  Character study identifier.
#' @param avisitn   Numeric visit number.
#' @param base_dir  Root directory.
#' @return Character analysis_window label, or "unknown" if not mapped.
resolve_analysis_window <- function(study_id, avisitn, base_dir = ".") {

  vm <- get_visit_mapping(study_id, base_dir = base_dir)

  matched <- vm %>%
    filter(avisitn == !!avisitn) %>%
    pull(analysis_window)

  if (length(matched) == 0) return("unknown")
  return(matched[[1]])
}
