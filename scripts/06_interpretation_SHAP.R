# =========================
# 06_interpretation_SHAP.R
# =========================

# --- Robust project root (works even when running from /scripts) ---
find_project_root <- function(start_dir = getwd(), max_up = 6) {
  cur <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
  for (i in 0:max_up) {
    if (file.exists(file.path(cur, "scripts", "01_setup.R"))) return(cur)
    parent <- normalizePath(file.path(cur, ".."), winslash = "/", mustWork = FALSE)
    if (identical(parent, cur)) break
    cur <- parent
  }
  NA_character_
}

PROJECT_ROOT <- find_project_root()
if (is.na(PROJECT_ROOT)) stop("Project root not found (missing scripts/01_setup.R). Open the .Rproj or run from project folder.")
setwd(PROJECT_ROOT)

source(file.path("scripts", "01_setup.R"))

# Load data
train_data <- readRDS(file.path(DIR_DATA_PROCESSED, "train_data.rds"))
test_data  <- readRDS(file.path(DIR_DATA_PROCESSED, "test_data.rds"))

# Load GBM bundle (model + best_iter)
gbm_bundle <- readRDS(file.path(DIR_OUTPUT_MODELS, "gbm_poisson_best.rds"))
gbm_model  <- gbm_bundle$model
best_iter  <- gbm_bundle$best_iter

if (!dir.exists(DIR_OUTPUT_TABLES)) dir.create(DIR_OUTPUT_TABLES, recursive = TRUE)
if (!dir.exists(DIR_OUTPUT_PLOTS)) dir.create(DIR_OUTPUT_PLOTS, recursive = TRUE)

# ----------------------------------------------------
# Keep factor levels stable (important for Make etc.)
# ----------------------------------------------------
factor_cols <- names(train_data)[sapply(train_data, is.factor)]
factor_levels <- lapply(train_data[factor_cols], levels)

apply_levels <- function(df) {
  for (nm in factor_cols) {
    df[[nm]] <- factor(df[[nm]], levels = factor_levels[[nm]])
  }
  df
}

train_data <- apply_levels(train_data)
test_data  <- apply_levels(test_data)

# ----------------------------------------------------
# Prepare data like in thesis code:
# drop ID + Gender 
# keep Exposure because offset(log(Exposure)) is used
# ----------------------------------------------------
drop_cols <- intersect(c("ID", "Gender"), names(train_data))
train_df <- train_data[, setdiff(names(train_data), drop_cols), drop = FALSE]
test_df  <- test_data[,  setdiff(names(test_data),  drop_cols), drop = FALSE]

# -------------------------
# Client (keep exactly your "high influence" one)
# -------------------------
client <- data.frame(
  County = factor("A", levels = c("A", "B", "C", "D")),
  Age = factor("18-24", levels = c("18-24", "25-34", "35-44", "45-54", "55-64", "65+")),
  EngPerfKW = factor("60-", levels = c("60-", "61-100", "101-150", "150+")),
  Weight = factor("1200-", levels = c("1200-", "1201-1600", "1601-2000", "2001+")),
  Make = factor("Opel", levels = c("Audi", "BMW", "Mazda", "Opel", "Renault", "VW")),
  CarAge = factor("16+", levels = c("0-3", "4-10", "11-15", "16+"))
)

# ----------------------------------------------------
# IMPORTANT: DALEX needs custom predict_function for GBM
# because we must pass n.trees = best_iter
# ----------------------------------------------------
predict_gbm <- function(model, newdata) {
  stats::predict(model, newdata = newdata, n.trees = best_iter, type = "response")
}

set.seed(SEED)
expl_gbm <- DALEX::explain(
  model = gbm_model,
  data  = train_df[, setdiff(names(train_df), "NClaims"), drop = FALSE],  # keep Exposure + predictors
  y     = train_df$NClaims,
  predict_function = predict_gbm,
  label = "GBM_poisson",
  verbose = FALSE
)

# ----------------------------------------------------
# Helper: predict_parts compatibility (B vs N)
# (older code used N=100, some DALEX versions use B=100)
# ----------------------------------------------------
safe_predict_parts <- function(explainer, new_observation, type, B = 100) {
  out <- tryCatch(
    DALEX::predict_parts(explainer = explainer, new_observation = new_observation, type = type, B = B),
    error = function(e1) {
      tryCatch(
        DALEX::predict_parts(explainer = explainer, new_observation = new_observation, type = type, N = B),
        error = function(e2) stop("predict_parts failed for type='", type, "':\n", e2$message)
      )
    }
  )
  out
}

# =========================
# 1) Variable importance (DALEX)
# =========================
set.seed(SEED)
imp <- DALEX::model_parts(explainer = expl_gbm, type = "variable_importance")
saveRDS(imp, file.path(DIR_OUTPUT_TABLES, "gbm_dalex_variable_importance.rds"))

p_imp <- plot(imp)
save_png_plot(file.path(DIR_OUTPUT_PLOTS, "gbm_variable_importance.png"), p_imp, 1200, 800)

# =========================
# 2) SHAP (client = row 5)
# =========================
set.seed(SEED)
shap_raw <- safe_predict_parts(explainer = expl_gbm, new_observation = client, type = "shap", B = 100)
saveRDS(shap_raw, file.path(DIR_OUTPUT_TABLES, "gbm_shap_raw_client.rds"))

p_shap_raw <- plot(shap_raw)
save_png_plot(file.path(DIR_OUTPUT_PLOTS, "gbm_shap_raw_client.png"), p_shap_raw, 1200, 800)

# =========================
# 3) SHAP aggregated (key output for your comparison)
# =========================
set.seed(SEED)
shap_agg <- safe_predict_parts(explainer = expl_gbm, new_observation = client, type = "shap_aggregated", B = 100)
saveRDS(shap_agg, file.path(DIR_OUTPUT_TABLES, "gbm_shap_aggregated_client.rds"))

p_shap_agg <- plot(shap_agg)
save_png_plot(file.path(DIR_OUTPUT_PLOTS, "gbm_shap_aggregated_client.png"), p_shap_agg, 1200, 800)

# =========================
# 4) Break-down (also like thesis)
# =========================
set.seed(SEED)
bd <- safe_predict_parts(explainer = expl_gbm, new_observation = client, type = "break_down", B = 100)
saveRDS(bd, file.path(DIR_OUTPUT_TABLES, "gbm_breakdown_client.rds"))

p_bd <- plot(bd)
save_png_plot(file.path(DIR_OUTPUT_PLOTS, "gbm_breakdown_client.png"), p_bd, 1200, 800)

# =========================
# 5) Profiles (PDP-style)
# model_profile object cannot be coerced to data.frame directly
# =========================
set.seed(SEED)
prof <- DALEX::model_profile(
  explainer = expl_gbm,
  variables = c("Age", "County", "Weight", "CarAge", "Make", "EngPerfKW"),
  type = "partial"
)

saveRDS(prof, file.path(DIR_OUTPUT_TABLES, "gbm_model_profile_partial.rds"))

p_prof <- plot(prof)
save_png_plot(file.path(DIR_OUTPUT_PLOTS, "gbm_model_profile_partial.png"), p_prof, 1400, 900)

# If you want a data.frame:
prof_df <- as.data.frame(prof$agr_profiles)
write.csv(prof_df, file.path(DIR_OUTPUT_TABLES, "gbm_model_profile_partial.csv"), row.names = FALSE)

cat("\n06_interpretation_SHAP DONE\n")
cat("Outputs saved to:\n")
cat(" -", DIR_OUTPUT_TABLES, "\n")
cat(" -", DIR_OUTPUT_PLOTS, "\n")
