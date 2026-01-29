#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Extract an ID from an API response
#'
#' Tries common id field names used by the platform.
#' @param resp API response list
#' @param candidates Candidate field names
#' @return Character scalar id
#' @export
extract_id <- function(resp,
                       candidates = c("id", "projectId", "_id", "experimentId", "gwasExperimentId")) {
  if (is.null(resp) || !is.list(resp)) {
    rlang::abort("Response is not a list; cannot extract an id.")
  }

  for (nm in candidates) {
    if (!is.null(resp[[nm]])) return(as.character(resp[[nm]]))
  }

  if (!is.null(resp$data) && is.list(resp$data)) {
    for (nm in candidates) {
      if (!is.null(resp$data[[nm]])) return(as.character(resp$data[[nm]]))
    }
  }

  rlang::abort(c(
    "Could not find an id field in the response.",
    i = paste("Tried:", paste(candidates, collapse = ", ")),
    i = "Inspect the response with `str(resp)` to find the right field."
  ))
}

#' Convert a VCF file into VarOmeter textDataset CSV string
#'
#' VarOmeter expects: SNP ID,P-value,Chr ID,Chr Position,Allele1,Allele2
#' VCF has no p-values; we assign default p_value to all variants.
#'
#' Robust to:
#' - gzipped VCFs (.vcf.gz) OR gzipped content even if extension is .vcf
#' - UTF-8 BOM before #CHROM
#' - blank lines and extra comment lines
#'
#' @param vcf_path Path to .vcf or .vcf.gz
#' @param p_value Default p-value to assign
#' @param max_variants Limit number of variants for quick tests
#' @return A single string with header + rows, ready for `textDataset`
#' @export
vcf_to_textDataset <- function(vcf_path, p_value = 1, max_variants = 5000) {
  if (!file.exists(vcf_path)) rlang::abort(paste("File not found:", vcf_path))

  # Detect gzip by magic bytes 1F 8B
  is_gz_magic <- FALSE
  raw2 <- tryCatch(readBin(vcf_path, what = "raw", n = 2), error = function(e) raw(0))
  if (length(raw2) == 2 && identical(as.integer(raw2), c(0x1f, 0x8b))) {
    is_gz_magic <- TRUE
  }

  con <- if (grepl("\\.gz$", vcf_path, ignore.case = TRUE) || is_gz_magic) {
    gzfile(vcf_path, open = "rt")
  } else {
    file(vcf_path, open = "r")
  }
  on.exit(close(con), add = TRUE)

  # Find header line (#CHROM...)
  header_line <- NULL
  repeat {
    line <- readLines(con, n = 1, warn = FALSE)
    if (length(line) == 0) break

    line <- sub("^\ufeff", "", line)     # remove BOM
    if (!nzchar(trimws(line))) next

    if (startsWith(line, "##")) next

    if (grepl("^#CHROM\\b", line)) {
      header_line <- line
      break
    }

    if (startsWith(line, "#")) next
  }

  if (is.null(header_line)) {
    rlang::abort("VCF header not found (#CHROM ...). File may not be a valid readable VCF.")
  }

  out <- c("SNP ID,P-value,Chr ID,Chr Position,Allele1,Allele2")
  n <- 0

  repeat {
    v <- readLines(con, n = 1, warn = FALSE)
    if (length(v) == 0) break

    v <- sub("^\ufeff", "", v)
    if (!nzchar(trimws(v))) next
    if (startsWith(v, "#")) next

    fields <- strsplit(v, "\t", fixed = TRUE)[[1]]
    if (length(fields) < 5) next

    chrom <- fields[1]
    pos   <- fields[2]
    id    <- fields[3]
    ref   <- fields[4]
    alt   <- fields[5]

    chr_id <- sub("^chr", "", chrom, ignore.case = TRUE)

    # ALT may have multiple values, pick first
    alt1 <- strsplit(alt, ",", fixed = TRUE)[[1]][1]

    # If ID missing, generate stable ID
    if (id == "." || !nzchar(id)) {
      id <- paste0(chrom, "-", pos, "-SNV-", ref, "-", alt1)
    }

    out <- c(out, paste(id, p_value, chr_id, pos, ref, alt1, sep = ","))
    n <- n + 1
    if (!is.null(max_variants) && n >= max_variants) break
  }

  paste(out, collapse = "\n")
}

#' Run VarOmeter and wait for results
#'
#' Strategy:
#' 1) Try to start the run via /api/rungwas
#' 2) Even if that call times out (e.g., HTTP 524), keep polling /api/resultsGwas
#'    because the backend may have started the job anyway.
#'
#' @param experiment_id Experiment ID
#' @param api_key Optional API key (otherwise ENIOS_API_KEY)
#' @param poll_seconds Poll interval in seconds
#' @param timeout_seconds Total wait timeout in seconds
#' @return Final results response (list)
#' Run VarOmeter and wait for results
#'
#' @export
run_varometer_wait <- function(experiment_id,
                               api_key = NULL,
                               poll_seconds = 20,
                               timeout_seconds = 7200) {

  tryCatch(
    run_varometer(experiment_id, api_key = api_key),
    error = function(e) {
      cli::cli_inform(c(
        "Run trigger failed or timed out; will continue polling results anyway.",
        i = conditionMessage(e)
      ))
      NULL
    }
  )

  start <- Sys.time()
  last_status <- NULL

  repeat {
    elapsed <- as.numeric(difftime(Sys.time(), start, units = "mins"))

    res <- tryCatch(
      get_varometer_results(experiment_id, api_key = api_key),
      error = function(e) {
        cli::cli_inform(c(
          "Polling error (will retry).",
          i = conditionMessage(e),
          i = sprintf("Elapsed: %.1f min", elapsed)
        ))
        NULL
      }
    )

    if (!is.null(res)) {
      status <- NULL
      if (is.list(res)) {
        status <- res$status %||% res$state %||% (res$data$status %||% res$data$state)
      }

      if (!is.null(status)) {
        st <- toupper(as.character(status))

        # Print only when status changes, plus elapsed time
        if (is.null(last_status) || !identical(st, last_status)) {
          cli::cli_inform(c(
            "Status update",
            i = paste("Status:", st),
            i = sprintf("Elapsed: %.1f min", elapsed)
          ))
          last_status <- st
        } else {
          cli::cli_inform(sprintf("Still %s (elapsed %.1f min)", st, elapsed))
        }

        if (st %in% c("COMPLETED", "COMPLETE", "DONE", "SUCCESS")) return(res)
        if (st %in% c("FAILED", "ERROR")) rlang::abort(c("VarOmeter run failed.", i = paste("Status:", st)))
      } else {
        # No status? if payload exists, return it
        if (length(res) > 0) return(res)
        cli::cli_inform(sprintf("Polling... no status field (elapsed %.1f min)", elapsed))
      }
    }

    if (as.numeric(difftime(Sys.time(), start, units = "secs")) > timeout_seconds) {
      rlang::abort(c(
        "Timed out waiting for results.",
        i = paste("timeout_seconds =", timeout_seconds),
        i = sprintf("Elapsed: %.1f min", elapsed)
      ))
    }

    Sys.sleep(poll_seconds)
  }
}
#' Wait for VarOmeter results without triggering a run
#'
#' Useful when /api/rungwas times out but the job is already RUNNING.
#' @param experiment_id Experiment ID
#' @param api_key Optional API key
#' @param poll_seconds Poll interval in seconds
#' @param timeout_seconds Total wait timeout in seconds
#' @export
wait_varometer_results <- function(experiment_id,
                                   api_key = NULL,
                                   poll_seconds = 60,
                                   timeout_seconds = 7200) {
  start <- Sys.time()
  repeat {
    elapsed <- as.numeric(difftime(Sys.time(), start, units = "mins"))

    res <- tryCatch(
      get_varometer_results(experiment_id, api_key = api_key),
      error = function(e) {
        cli::cli_inform(c("Polling error (will retry).", i = conditionMessage(e)))
        NULL
      }
    )

    if (!is.null(res)) {
      status <- NULL
      if (is.list(res)) status <- res$status %||% res$state %||% (res$data$status %||% res$data$state)

      if (!is.null(status)) {
        st <- toupper(as.character(status))
        cli::cli_inform(c("Polling results...", i = paste("Status:", st), i = sprintf("Elapsed: %.1f min", elapsed)))

        if (st %in% c("COMPLETED", "COMPLETE", "DONE", "SUCCESS")) return(res)
        if (st %in% c("FAILED", "ERROR")) rlang::abort(c("VarOmeter run failed.", i = paste("Status:", st)))
      } else {
        if (length(res) > 0) return(res)
        cli::cli_inform(sprintf("Polling... no status field (elapsed %.1f min)", elapsed))
      }
    }

    if (as.numeric(difftime(Sys.time(), start, units = "secs")) > timeout_seconds) {
      rlang::abort(c("Timed out waiting for results.", i = paste("timeout_seconds =", timeout_seconds)))
    }

    Sys.sleep(poll_seconds)
  }
}

