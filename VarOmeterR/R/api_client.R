#' VarOmeter API base URL
#'
#' Reads from `options(varometer.base_url=...)` or defaults to the dev host.
#' @keywords internal
varometer_base_url <- function() {
  getOption("varometer.base_url", "https://bim3.e-nios.com")
}

#' Get API key
#'
#' Uses explicit `api_key` if provided, otherwise reads `ENIOS_API_KEY`.
#' @param api_key Character scalar.
#' @keywords internal
varometer_api_key <- function(api_key = NULL) {
  if (!is.null(api_key) && nzchar(api_key)) return(api_key)

  key <- Sys.getenv("ENIOS_API_KEY", unset = "")
  if (!nzchar(key)) {
    rlang::abort(
      c(
        "Missing API key.",
        i = "Set env var ENIOS_API_KEY, e.g. Sys.setenv(ENIOS_API_KEY = '...')",
        i = "Or pass `api_key=` explicitly."
      )
    )
  }
  key
}

#' Create default headers for VarOmeter API calls
#'
#' Same style as BioInfoMiner:
#' api_key <- "..."
#' headers <- varometer_headers(api_key)
#'
#' @param api_key API key string
#' @return Named character vector of headers
#' @export
varometer_headers <- function(api_key) {
  c(
    `Content-Type`  = "application/json",
    `enios-api-key` = api_key
  )
}

#' Perform a VarOmeter API request
#'
#' Adds reliability improvements:
#' - client-side timeout
#' - retries on transient HTTP errors (including 524 gateway timeout)
#'
#' @param method HTTP method (e.g. 'GET', 'POST', 'DELETE')
#' @param path API path starting with /api/...
#' @param api_key API key (optional; otherwise uses ENIOS_API_KEY)
#' @param query Named list for query parameters
#' @param body Body as a named list (encoded as JSON) OR a scalar (for delete-by-id)
#' @param timeout_seconds Per-request timeout (client side)
#' @param max_tries Number of tries for transient failures
#' @return Parsed JSON as a list (or raw text if non-JSON)
#' @keywords internal
varometer_request <- function(method,
                              path,
                              api_key = NULL,
                              query = NULL,
                              body = NULL,
                              timeout_seconds = 180,
                              max_tries = 5) {
  base_url <- varometer_base_url()
  key <- varometer_api_key(api_key)

  req <- httr2::request(paste0(base_url, path)) |>
    httr2::req_method(method) |>
    httr2::req_headers(`enios-api-key` = key) |>
    httr2::req_timeout(timeout_seconds) |>
    httr2::req_retry(
      max_tries = max_tries,
      backoff = ~ min(60, 2 ^ (.x - 1)), # 1,2,4,8,... seconds up to 60
      is_transient = function(resp) {
        st <- httr2::resp_status(resp)
        st %in% c(429, 500, 502, 503, 504, 524)
      }
    )

  if (!is.null(query)) {
    req <- httr2::req_url_query(req, !!!query)
  }

  # IMPORTANT:
  # The API doc shows JSON bodies even on GET for /api/rungwas and /api/resultsGwas.
  # Also DELETE uses a raw JSON string id.
  if (!is.null(body)) {
    req <- req |>
      httr2::req_headers(`Content-Type` = "application/json") |>
      httr2::req_body_json(body, auto_unbox = TRUE)
  }

  resp <- httr2::req_perform(req)

  if (httr2::resp_status(resp) >= 400) {
    txt <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")
    rlang::abort(c(
      sprintf("API request failed [%s %s] (HTTP %s).", method, path, httr2::resp_status(resp)),
      i = if (nzchar(txt)) txt else "No response body."
    ))
  }

  ct <- httr2::resp_header(resp, "content-type")
  if (!is.null(ct) && grepl("application/json", ct, fixed = TRUE)) {
    return(httr2::resp_body_json(resp, simplifyVector = FALSE))
  }

  httr2::resp_body_string(resp)
}
