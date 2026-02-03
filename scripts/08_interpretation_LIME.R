# =========================
# 08_interpretation_LIME.R
# =========================
source(file.path("scripts", "01_setup.R"))

# -------------------------
# Load data + model
# -------------------------
train_data <- readRDS(file.path(DIR_DATA_PROCESSED, "train_data.rds"))
test_data  <- readRDS(file.path(DIR_DATA_PROCESSED, "test_data.rds"))

gbm_bundle <- readRDS(file.path(DIR_OUTPUT_MODELS, "gbm_poisson_best.rds"))
gbm_model  <- gbm_bundle$model
best_iter  <- gbm_bundle$best_iter

if (!dir.exists(DIR_OUTPUT_TABLES)) dir.create(DIR_OUTPUT_TABLES, recursive = TRUE)
if (!dir.exists(DIR_OUTPUT_PLOTS)) dir.create(DIR_OUTPUT_PLOTS, recursive = TRUE)

cat("Using best_iter =", best_iter, "\n")

# -------------------------
# Prepare X/y 
# -------------------------
cols_drop <- intersect(c("ID", "Gender"), names(train_data))
train_df <- train_data[, setdiff(names(train_data), cols_drop), drop = FALSE]

y_train <- train_df$NClaims
X_train <- train_df[, setdiff(names(train_df), c("NClaims", "Exposure")), drop = FALSE]

# -------------------------
# Client 
# -------------------------
client <- data.frame(
  County    = factor("A",      levels = levels(train_df$County)),
  Age       = factor("18-24",  levels = levels(train_df$Age)),
  EngPerfKW = factor("60-",    levels = levels(train_df$EngPerfKW)),
  Weight    = factor("1200-",  levels = levels(train_df$Weight)),
  Make      = factor("Opel",   levels = levels(train_df$Make)),
  CarAge    = factor("16+",    levels = levels(train_df$CarAge))
)

# -------------------------
# Predict wrapper 
# -------------------------
predict_gbm_best <- function(model, newdata) {
  gbm::predict.gbm(
    object = model,
    newdata = newdata,
    n.trees = best_iter,
    type = "response"
  )
}

# -------------------------
# Explainer
# -------------------------
set.seed(SEED)
expl_gbm <- DALEX::explain(
  model = gbm_model,
  data  = X_train,
  y     = y_train,
  predict_function = predict_gbm_best,
  label = "GBM_poisson",
  verbose = FALSE
)

# -------------------------
# LIME (iml surrogate) 
# -------------------------
set.seed(SEED)
lime_gbm <- DALEXtra::predict_surrogate(
  explainer = expl_gbm,
  new_observation = client,
  k = 4,
  type = "iml",
  seed = SEED
)

print(lime_gbm$results)

# Plot 
p_lime <- plot(lime_gbm)
print(p_lime)

save_plot(p_lime, "lime_gbm_client.png", width = 10, height = 5, dpi = 300)

cat("08_interpretation_LIME DONE | best_iter =", best_iter, "\n")
