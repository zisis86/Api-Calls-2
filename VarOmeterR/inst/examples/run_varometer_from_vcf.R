library(VarOmeterR)

# --- 1) Auth (BioInfoMiner-style) ---
api_key <- "leq3vxq1812k4of6xrbdy2ekj43u4up3"
headers <- varometer_headers(api_key)  # optional helper, same style as BioInfoMiner
Sys.setenv(ENIOS_API_KEY = api_key)

# Dev base URL from doc
options(varometer.base_url = "https://bim3.e-nios.com")

# --- 2) Create project ---
p <- create_project(
  title = "VarOmeter VCF test project2",
  description = "Testing VarOmeter using VCF converted to textDataset"
)
project_id <- extract_id(p, c("id","projectId","_id"))
print(project_id)

# --- 3) Convert VCF -> textDataset ---
# Use your uploaded file path (adjust if you copied it elsewhere)
vcf_path <- "inst/examples/random_1_healthy_HG00096.vcf"
textDataset <- vcf_to_textDataset(vcf_path, p_value = 1, max_variants = 2000)
textDataset <- vcf_to_textDataset(vcf_path, p_value = 1, max_variants = 200)

# --- 4) Create VarOmeter experiment ---
# Parameters follow the example structure in the API doc
params <- list(
  lncRNA = TRUE,
  miRNA = TRUE,
  pvalue = 0.00000001,
  pvalueFlag = FALSE,
  consequences = list(list(on = TRUE, name = "intergenic_variant")),
  chromosomes  = list(list(on = TRUE, name = "1")),
  sources      = list(list(on = TRUE, name = "vep")),
  types        = list(list(on = TRUE, name = "distance"))
)

e <- create_varometer_experiment(
  title = "VCF-derived VarOmeter experiment2",
  description = "Converted VCF -> GWAS CSV textDataset",
  project_id = project_id,
  textDataset = textDataset,
  parameters = params
)

experiment_id <- extract_id(e, c("id","experimentId","gwasExperimentId"))
print(experiment_id)

# --- 5) Run + wait for results ---
final <- run_varometer_wait(experiment_id, poll_seconds = 60, timeout_seconds = 7200)
str(final, max.level = 2)
