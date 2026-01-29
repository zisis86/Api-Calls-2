#' Create a new project
#'
#' Endpoint: POST /api/projects
#' @param title Project title
#' @param description Project description
#' @param api_key Optional API key (otherwise ENIOS_API_KEY)
#' @return API response (list)
#' @export
create_project <- function(title, description = "", api_key = NULL) {
  body <- list(title = title, description = description)
  varometer_request("POST", "/api/projects", api_key = api_key, body = body)
}

#' Delete a project
#'
#' Endpoint: DELETE /api/projects
#' The API expects the id as a JSON string in the body.
#' @param project_id Project ID
#' @param api_key Optional API key (otherwise ENIOS_API_KEY)
#' @return API response
#' @export
delete_project <- function(project_id, api_key = NULL) {
  varometer_request("DELETE", "/api/projects", api_key = api_key, body = project_id)
}

#' Create a VarOmeter experiment (GWAS form)
#'
#' Endpoint: POST /api/gwasform
#' @param title Experiment title
#' @param project_id Project ID
#' @param textDataset CSV string:
#'   SNP ID,P-value,Chr ID,Chr Position,Allele1,Allele2 + rows
#' @param description Optional description
#' @param parameters Additional parameters
#' @param api_key Optional API key (otherwise ENIOS_API_KEY)
#' @return API response (list)
#' @export
create_varometer_experiment <- function(title,
                                        project_id,
                                        textDataset,
                                        description = "",
                                        parameters = list(),
                                        api_key = NULL) {
  params <- c(list(textDataset = textDataset), parameters)

  body <- list(
    title = title,
    description = description,
    project = project_id,
    parameters = params
  )

  # Creating experiment can also be slow if textDataset is large
  varometer_request(
    "POST",
    "/api/gwasform",
    api_key = api_key,
    body = body,
    timeout_seconds = 240,
    max_tries = 5
  )
}

#' Run VarOmeter experiment
#'
#' Endpoint: GET /api/rungwas (JSON body with experimentId)
#' Note: backend may be slow; we use longer timeout + retries to avoid 524.
#' @param experiment_id Experiment ID
#' @param api_key Optional API key (otherwise ENIOS_API_KEY)
#' @return API response (list)
#' @export
run_varometer <- function(experiment_id, api_key = NULL) {
  body <- list(experimentId = experiment_id)
  varometer_request(
    "GET",
    "/api/rungwas",
    api_key = api_key,
    body = body,
    timeout_seconds = 300,
    max_tries = 6
  )
}

#' Get VarOmeter results
#'
#' Endpoint: GET /api/resultsGwas (JSON body with gwasExperimentId)
#' @param experiment_id Experiment ID
#' @param api_key Optional API key (otherwise ENIOS_API_KEY)
#' @return API response (list)
#' @export
get_varometer_results <- function(experiment_id, api_key = NULL) {
  body <- list(gwasExperimentId = experiment_id)
  varometer_request(
    "GET",
    "/api/resultsGwas",
    api_key = api_key,
    body = body,
    timeout_seconds = 180,
    max_tries = 6
  )
}
