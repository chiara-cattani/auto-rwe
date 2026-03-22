# =============================================================================
# 01_data_loading.R  —  DATA LOADING LAYER
#
# Responsibilities:
#   - Locate and read SDTM / ADaM CSV files for a given study
#   - Apply minimal, generic cleaning
#   - Return a consistent tibble structure
#
# Public functions:
#   load_study(study_id, base_dir)  -> named list of domain tibbles
#   get_dataset(study_id, domain, base_dir) -> tibble for one domain
# =============================================================================

library(dplyr)
library(readr)
library(stringr)

# Internal study cache (avoids re-reading files within a session)
.study_cache <- new.env(parent = emptyenv())

# -----------------------------------------------------------------------------
#' Load all datasets for a study into a named list
#'
#' @param study_id   Character. Study identifier matching the folder name.
#' @param base_dir   Root directory of the project (default: ".").
#' @param refresh    Logical. Force re-read even if cached.
#' @return Named list of tibbles, one per CSV file found.
# -----------------------------------------------------------------------------
load_study <- function(study_id, base_dir = ".", refresh = FALSE) {

  cache_key <- paste0(study_id, "|", normalizePath(base_dir, mustWork = FALSE))

  if (!refresh && exists(cache_key, envir = .study_cache)) {
    return(get(cache_key, envir = .study_cache))
  }

  study_dir <- file.path(base_dir, "data", "studies", study_id)

  if (!dir.exists(study_dir)) {
    stop(sprintf(
      "[load_study] Directory not found for study '%s': %s",
      study_id, study_dir
    ))
  }

  csv_files <- list.files(study_dir, pattern = "\\.csv$", full.names = TRUE)

  if (length(csv_files) == 0) {
    stop(sprintf(
      "[load_study] No CSV files found in %s. Did you run simulate_all_studies()?",
      study_dir
    ))
  }

  datasets <- lapply(csv_files, function(f) {
    domain_name <- tools::file_path_sans_ext(basename(f))
    tbl <- readr::read_csv(f, show_col_types = FALSE, progress = FALSE)
    tbl <- .clean_dataset(tbl, domain = domain_name)
    tbl
  })

  names(datasets) <- toupper(
    tools::file_path_sans_ext(basename(csv_files))
  )

  assign(cache_key, datasets, envir = .study_cache)
  message(sprintf(
    "[load_study] Loaded %d domain(s) for '%s': %s",
    length(datasets), study_id, paste(names(datasets), collapse = ", ")
  ))

  return(datasets)
}

# -----------------------------------------------------------------------------
#' Get a single domain dataset for a study
#'
#' @param study_id   Character. Study identifier.
#' @param domain     Character. Domain name (e.g. "ADQS", "ADSL"). Case-insensitive.
#' @param base_dir   Root directory of the project.
#' @return Tibble for the requested domain.
# -----------------------------------------------------------------------------
get_dataset <- function(study_id, domain, base_dir = ".") {

  domain <- toupper(domain)
  study_data <- load_study(study_id, base_dir = base_dir)

  if (!domain %in% names(study_data)) {
    stop(sprintf(
      "[get_dataset] Domain '%s' not found for study '%s'. Available: %s",
      domain, study_id, paste(names(study_data), collapse = ", ")
    ))
  }

  return(study_data[[domain]])
}

# -----------------------------------------------------------------------------
# Internal: generic dataset cleaning
# -----------------------------------------------------------------------------
.clean_dataset <- function(tbl, domain = NULL) {

  # Trim whitespace from character columns
  tbl <- tbl %>%
    mutate(across(where(is.character), str_trim))

  # Standardize common flag columns to NA/Y
  flag_cols <- intersect(
    names(tbl),
    c("ABLFL", "ANL01FL", "FASFL", "SAFFL", "PPSFL", "MITTFL")
  )
  for (col in flag_cols) {
    tbl[[col]] <- ifelse(tbl[[col]] == "Y", "Y", NA_character_)
  }

  # Ensure numeric columns are numeric
  num_cols <- intersect(names(tbl), c("AVISITN", "AVAL", "BASE", "CHG",
                                       "BAGE", "AGE", "AVAL2"))
  for (col in num_cols) {
    if (!is.numeric(tbl[[col]])) {
      tbl[[col]] <- suppressWarnings(as.numeric(tbl[[col]]))
    }
  }

  return(tbl)
}

# -----------------------------------------------------------------------------
#' Clear the in-memory study cache
# -----------------------------------------------------------------------------
clear_study_cache <- function() {
  rm(list = ls(envir = .study_cache), envir = .study_cache)
  message("[load_study] Cache cleared.")
  invisible(NULL)
}
