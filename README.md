# Non-Life Insurance Client Segmentation

This repository presents an **end-to-end analytical pipeline for non-life insurance client segmentation and risk modeling**, based on my MSc thesis work and further refactored for clarity, reproducibility, and public sharing.

The project demonstrates:
- actuarial-style frequency modeling (GLM / ZIP),
- modern machine learning approaches (GBM),
- and **model interpretability using SHAP / break-down explanations**, which are particularly relevant in regulated environments such as insurance.

All **data are anonymized and excluded** from the repository.

---

## Project Structure

```text
.
├── scripts/                 # Numbered pipeline scripts (01–08)
│   ├── 01_setup.R
│   ├── 02_import_clean.R
│   ├── 03_feature_engineering.R
│   ├── 04_glm_models.R
│   ├── 05_gbm_models.R
│   ├── 06_interpretation_SHAP.R
│   ├── 07_plots.R
│   └── 08_utils.R
│
├── notebooks/               # Executable R Markdown pipeline
│   └── claims_pipeline_notebook.Rmd
│
├── data/
│   ├── raw/                 # (ignored) original data
│   └── processed/           # (ignored) intermediate datasets
│
├── output/
│   ├── models/              # saved model objects
│   ├── tables/              # evaluation metrics
│   └── plots/               # generated figures
│
├── documents/
│   └── thesis_client_segmentation.pdf           
│
└── README.md
```

---

## Modeling Overview

### 1. Classical Actuarial Models
- **Poisson GLM**
- **Negative Binomial GLM**
- **Zero-Inflated Poisson (ZIP)**

These models serve as strong, interpretable baselines commonly used in pricing and reserving.

### 2. Gradient Boosting Machine (GBM)
- Poisson loss with exposure offset
- Cross-validated hyperparameters

### 3. Model Interpretability (Key Focus)
The GBM is interpreted using:
- **SHAP values**
- **SHAP aggregated (waterfall-style)**
- **Break-down explanations**
- **PDP / ALE / ICE profiles**

These outputs bridge the gap between predictive power and explainability.

---

## Example Explanations

The following plots are included in the repository under `figures/`:

- **SHAP aggregated explanation (client-level)**  
- **Raw SHAP contributions**
- **Break-down explanation**
- **Partial dependence / ALE / ICE curves**
- **LIME explanation plot**

These figures illustrate how individual risk factors contribute to predicted claim frequency in an intuitive way.

---

## Reproducibility

You can run the full pipeline via:

### Option A: R Scripts
```r
source("scripts/01_setup.R")
source("scripts/02_import_clean.R")
...
```

### Option B: R Markdown Notebook (recommended)
```text
notebooks/claims_pipeline_notebook.Rmd
```

The notebook automatically:
- detects the project root,
- runs the full pipeline,
- reproduces tables, models, and plots.

---

## Data & Privacy

- No real client data are included
- All variable names are generic
- The original dataset is replaced by a local placeholder

This repository is **safe for public sharing**.

---

## Background

This project is based on my MSc thesis in applied statistics / actuarial modeling and later extended with:
- cleaner pipeline design,
- stronger validation,
- modern explainability tooling.

The focus is practical, not academic perfection.

---

## Contact

**Karol Jurik**  
📍 Bratislava, SK  
🔗 [LinkedIn](www.linkedin.com/in/karoljurik) / [GitHub](https://github.com/karol-jurik)

---

> *Interpretability is not optional in insurance — it is a requirement.*
