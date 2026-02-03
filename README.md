# Claims Frequency Modeling Pipeline (GLM vs GBM)

This repository contains a **complete, reproducible modeling pipeline** for insurance claims frequency modeling and interpretation.
It is based on my MSc thesis work and refactored into a **clean, script-based workflow** suitable for review, reuse, and extension.

⚠️ **Important**  
- No proprietary data are included.
- All dataset names, paths, and identifiers are **neutralized**.
- The pipeline runs only if you provide your own local dataset (ignored by git).

---

## Project Goals

- Model **claim frequency** using classical actuarial models (GLM, ZIP, NB)
- Compare them with **tree-based models** (GBM)
- Evaluate models using **cross-validation and holdout MSE**
- Provide **model interpretability**:
  - GLM coefficients
  - GBM: SHAP, SHAP aggregated, PDP, ALE, ICE, LIME
- Deliver a **fully reproducible notebook** suitable for presentation

---

## Repository Structure

```text
Thesis_ClientSegmentation/
│
├── scripts/                # Core pipeline (01–08)
│   ├── 01_setup.R          # Global config, paths, seed, packages
│   ├── 02_import_clean.R   # Load + clean raw data (local only)
│   ├── 03_features_split.R# Feature engineering + train/test split
│   ├── 04_glm_models.R     # Poisson / NB / ZIP models
│   ├── 05_gbm_models.R     # GBM training + tuning
│   ├── 06_gbm_interpret.R  # SHAP, SHAP aggregated, BD
│   ├── 07_gbm_profiles.R  # PDP, ALE, ICE
│   └── 08_lime.R           # Local explanations (LIME)
│
├── notebooks/
│   └── claims_pipeline_notebook.Rmd   # End-to-end runnable notebook
│
├── data/
│   ├── raw/                # Local raw data (gitignored)
│   └── processed/          # Processed .rds files (gitignored)
│
├── output/
│   ├── models/             # Saved models (.rds)
│   ├── tables/             # Metrics, summaries
│   └── figures/            # Plots
│
├── .gitignore
└── README.md
```

---

## How to Run the Project

### 1. Clone the repository
```bash
git clone <your-repo-url>
cd Thesis_ClientSegmentation
```

### 2. Add your local dataset
Place your dataset here:
```text
data/raw/claims_data.xlsx
```

> This file is **never committed**.

### 3. Run the full pipeline (recommended)
Open and knit:
```text
notebooks/claims_pipeline_notebook.Rmd
```

The notebook:
- Automatically detects the project root
- Runs scripts **01 → 08**
- Produces all results, tables, and plots

### 4. Script-only execution (optional)
You can also run scripts manually in order:
```r
source("scripts/01_setup.R")
source("scripts/02_import_clean.R")
...
source("scripts/08_lime.R")
```

---

## Modeling Overview

### Classical Models
- Poisson GLM
- Negative Binomial GLM
- Zero-Inflated Poisson (ZIP)

**Evaluation**:
- K-fold cross-validation
- Holdout MSE
- LogLik, AIC, BIC

### Tree-Based Model
- Gradient Boosting Machine (GBM, Poisson loss)

**Tuning**:
- Reduced parameter grid (thesis-informed)
- CV-based early stopping

---

## Model Interpretation

### GLM
- Direct coefficient interpretation (log-frequency scale)
- Standard actuarial baseline

### GBM
- SHAP (local explanation)
- SHAP aggregated (global contribution, GLM-comparable)
- Break-down & interactions
- PDP / ALE / ICE
- LIME (local surrogate)

A **fixed representative client** is intentionally used for interpretability consistency.

---

## Reproducibility

- Single global `SEED`
- Explicit train/test split
- All randomness controlled
- Notebook runnable from any folder via root detection

---

## What This Project Is (and Is Not)

✔ Clean, readable, thesis-consistent  
✔ Suitable for GitHub / hiring review  
✔ Focus on correctness and clarity  

✘ Not a Kaggle-style hyperparameter arms race  
✘ Not dependent on proprietary data  

---

## Next Steps (Optional)

- Extend GBM → XGBoost
- Severity modeling
- Frequency × Severity pricing
- Calibration plots

---

## Author

Prepared as part of MSc thesis work and refactored for reproducible research and portfolio presentation.
