
# Non-Life Insurance Client Segmentation (GLM & GBM with SHAP)

This repository presents an end-to-end **insurance analytics pipeline** focused on **claim frequency modeling** and **client segmentation** in **non-life insurance**.

The project is based on my MSc thesis work and was later refactored into a clean, reproducible pipeline suitable for public sharing (no proprietary data included).  
All models are trained on **anonymized / local-only data** which are **not part of this repository**.

---

## 🎯 Project Goals

- Model claim frequency using classical actuarial models and modern ML
- Compare **GLM-based approaches** with **tree-based models**
- Provide **clear, interpretable explanations** of model behavior
- Demonstrate practical, production-style R project structure

---

## 🧠 Models Implemented

### Classical Models
- **Poisson GLM**
- **Negative Binomial GLM**
- **Zero-Inflated Poisson (ZIP)**

### Machine Learning
- **Gradient Boosting Machine (GBM, Poisson loss)**

---

## 🔍 Model Interpretability (Key Focus)

- SHAP (local & aggregated)
- Break-down plots
- PDP / ALE / ICE

These methods make tree-based models transparent and comparable with GLMs.

---

---
## Model Explainability – Example

![Aggregated SHAP](output/plots/gbm_shap_aggregated_client.png)
![Break Down](output/plots/gbm_breakdown_client.png)

---

## 📁 Repository Structure

```
.
├── scripts/
├── notebooks/
├── data/
├── output/
│   ├── models/
│   ├── tables/
│   └── plots/
├── README.md
└── Thesis_ClientSegmentation.Rproj
```

---

## ▶️ How to Run

Open the notebook:

```
notebooks/claims_pipeline_notebook.Rmd
```

and run **Run All**.

---

## 🔒 Data Privacy

No real data are included.  
All sensitive inputs are ignored via `.gitignore`.

---

## 📬 Author

**Karol Jurik**  
GitHub: https://github.com/karol-jurik
