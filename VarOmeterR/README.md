# VarOmeter Library 

Goal: VarOmeter is an R package for interacting with the VarOmeter API. It helps create projects, run experiments, and fetch results.
GitHub: https://github.com/zisis86/Api_calls_R/edit/main/VarOmeter

Implementation of the tool includes the following sections that enables you to:
- Projects : Create VarOmeter projects / Delete of a Project.
- Data : Upload datasets  
- Executions/Experiments: Create and run experiments / Delete an Experiment / Wait for execution to finish  
- Results : Retrieve analysis results / Get & Save results locally in structured folders 


The repository in Github contains the following files:
- R repository: Includes the script **functions.R ** with the functions for the execution of each section and  **main.R** with the base script of the tool.
- DESCRIPTION :  This file provides overall metadata about the package.
- NAMESPACE : Defines the functions, classes, and methods that are imported into the package namespace, and exported for users.

R Studio Environment:
 Language: R | It is recommended to use R Studio environment for the installation and execution of the Library. 

GitHub repository:
https://github.com/zisis86/Api_calls_R

---

## Overview

With VarOmeter you can:

- Create and manage VarOmeter projects
- Upload and process biological datasets
- Run Varometer experiments
- Retrieve and store analysis results locally
- Interactively explore results using a DAG-based viewer

---

## Package Structure

```text
VarOmeter/
├── DESCRIPTION
├── NAMESPACE
├── R/
│   ├── functions.R
│   ├── helpers.R
│   ├── constant_variables.R
│   └── systemic_viewer.R
├── inst/
│   └── examples/
│       └── 
└── README.md
```

---
functions.R contains the main API-facing functions.
helpers.R and constant_variables.R define internal helpers and paths.

## Install (local dev)

```r
# install.packages("devtools")
devtools::install_local(".")
```


## Authentication
```r
api_key <- "YOUR_API_KEY_HERE"

headers <- varometer_headers(api_key)
headers
Sys.setenv(ENIOS_API_KEY = api_key)
```
## Base URL
```r
options(varometer.base_url = "https://bim3.e-nios.com")
```
## Example using a VCF as input
```r
library(VarOmeterR)

api_key <- "YOUR_API_KEY_HERE"
Sys.setenv(ENIOS_API_KEY = api_key)

# 1) Create a project
p <- create_project("VCF test project", "Testing VarOmeter with VCF-derived variants")
project_id <- extract_id(p, c("id","projectId","_id"))

# 2) Convert VCF -> textDataset
vcf_path <- "random_1_healthy_HG00096.vcf"
textDataset <- vcf_to_textDataset(vcf_path, p_value = 1, max_variants = 2000)

# 3) Create experiment
params <- list(
  lncRNA = TRUE,
  miRNA = TRUE,
  pvalue = 1e-8,
  pvalueFlag = FALSE,
  consequences = list(list(on = TRUE, name = "intergenic_variant")),
  chromosomes  = list(list(on = TRUE, name = "1")),
  sources      = list(list(on = TRUE, name = "vep")),
  types        = list(list(on = TRUE, name = "distance"))
)

e <- create_varometer_experiment(
  title = "VCF-derived experiment",
  description = "Variants from VCF converted to textDataset",
  project_id = project_id,
  textDataset = textDataset,
  parameters = params
)

experiment_id <- extract_id(e, c("id","experimentId","gwasExperimentId"))

# 4) Run + wait
final <- run_varometer_wait(experiment_id, poll_seconds = 5, timeout_seconds = 600)
final
```


##Real example with vcf 
```r
library(VarOmeterR)

api_key <- "leq3vxq1812k4of6xrbdy2ekj43u4up3"
Sys.setenv(ENIOS_API_KEY = api_key)
options(varometer.base_url = "https://bim3.e-nios.com")

p <- create_project("Test from VCF", "Created via VarOmeterR")
project_id <- extract_id(p, c("id","projectId","_id"))

textDataset <- vcf_to_textDataset("/mnt/data/random_1_healthy_HG00096.vcf", p_value = 1, max_variants = 2000)

params <- list(
  lncRNA = TRUE,
  miRNA = TRUE,
  pvalue = 1e-8,
  pvalueFlag = FALSE,
  consequences = list(list(on = TRUE, name = "intergenic_variant")),
  chromosomes  = list(list(on = TRUE, name = "1")),
  sources      = list(list(on = TRUE, name = "vep")),
  types        = list(list(on = TRUE, name = "distance"))
)

e <- create_varometer_experiment(
  title = "Experiment from VCF",
  project_id = project_id,
  textDataset = textDataset,
  parameters = params
)

experiment_id <- extract_id(e, c("id","experimentId","gwasExperimentId"))

final <- run_varometer_wait(experiment_id)
str(final, max.level = 2)
```

## Contact

E-NIOS Bioinformatics Services  
Email: zisis@e-nios.com  
Website: https://www.e-nios.com/

