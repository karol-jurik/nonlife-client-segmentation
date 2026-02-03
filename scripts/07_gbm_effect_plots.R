# =========================
# 07_gbm_profiles_plots.R
# PDP + ALE + ICE (Age) for GBM
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
# Prepare data for DALEX
# (like thesis: remove ID, Gender; use X without NClaims & Exposure)
# -------------------------
train_df <- train_data
test_df  <- test_data

# Keep consistent with your pipeline (ID may exist)
if ("ID" %in% names(train_df)) train_df <- subset(train_df, select = -c(ID))
if ("ID" %in% names(test_df))  test_df  <- subset(test_df,  select = -c(ID))

if ("Gender" %in% names(train_df)) train_df <- subset(train_df, select = -c(Gender))
if ("Gender" %in% names(test_df))  test_df  <- subset(test_df,  select = -c(Gender))

# X for explainer = predictors only (no NClaims, no Exposure)
X_train <- train_df[, -c(1, 2), drop = FALSE]

# -------------------------
# Client (KEEP EXACTLY like your thesis)
# -------------------------
client <- data.frame(
  County    = factor("A",     levels = c("A", "B", "C", "D")),
  Age       = factor("18-24", levels = c("18-24", "25-34", "35-44", "45-54", "55-64", "65+")),
  EngPerfKW = factor("60-",   levels = c("60-", "61-100", "101-150", "150+")),
  Weight    = factor("1200-", levels = c("1200-", "1201-1600", "1601-2000", "2001+")),
  Make      = factor("Opel",  levels = c("Audi", "BMW", "Mazda", "Opel", "Renault", "VW")),
  CarAge    = factor("16+",   levels = c("0-3", "4-10", "11-15", "16+"))
)

# -------------------------
# DALEX explainer
# Important: use predict_function that always uses best_iter
# -------------------------
pred_fun_gbm <- function(model, newdata) {
  gbm::predict.gbm(
    object = model,
    newdata = newdata,
    n.trees = best_iter,
    type = "response"
  )
}

expl_gbm <- DALEX::explain(
  model = gbm_model,
  data  = X_train,
  y     = train_df$NClaims,   # (DALEX needs y; interpretability still OK)
  predict_function = pred_fun_gbm,
  label = "GBM_poisson_rate"
)

# -------------------------
# 1) PDP (Age)
# -------------------------
pdp_age <- DALEX::model_profile(
  explainer = expl_gbm,
  variables = "Age",
  type = "partial"
)

pdp_df <- as.data.frame(pdp_age$agr_profiles) %>%
  dplyr::select(`_x_`, `_yhat_`) %>%
  dplyr::rename(
    Age = `_x_`,
    prediction_pdp = `_yhat_`
  )

# -------------------------
# 2) ALE (Age)
# -------------------------
ale_age <- DALEX::model_profile(
  explainer = expl_gbm,
  variables = "Age",
  type = "accumulated"
)

ale_df <- as.data.frame(ale_age$agr_profiles) %>%
  dplyr::select(`_x_`, `_yhat_`) %>%
  dplyr::rename(
    Age = `_x_`,
    prediction_ale = `_yhat_`
  )

# -------------------------
# 3) ICE (Age) for this client
# -------------------------
ice_age <- DALEX::predict_profile(
  explainer = expl_gbm,
  new_observation = client,
  variables = "Age"
)

# In DALEX, ICE is stored in $profiles
ice_df <- as.data.frame(ice_age) %>%
  dplyr::select(Age, `_yhat_`) %>%
  dplyr::rename(prediction_ice = `_yhat_`) %>%
  dplyr::distinct()

# -------------------------
# Combine + add Age distribution (relative frequency)
# -------------------------
age_dist <- train_df %>%
  dplyr::group_by(Age) %>%
  dplyr::summarise(Count = n() / nrow(train_df), .groups = "drop")

plot_df <- age_dist %>%
  dplyr::left_join(pdp_df, by = "Age") %>%
  dplyr::left_join(ale_df, by = "Age") %>%
  dplyr::left_join(ice_df, by = "Age")

# Ensure ordering (important for lines)
plot_df$Age <- factor(plot_df$Age, levels = levels(client$Age))

# -------------------------
# Plot (single combined figure like thesis)
# -------------------------
p <- ggplot(plot_df, aes(x = Age)) +
  geom_bar(aes(y = Count, fill = "Relative frequency"), stat = "identity") +
  geom_line(aes(y = prediction_pdp, group = 1, color = "PDP"), linewidth = 1) +
  geom_point(aes(y = prediction_pdp, color = "PDP"), size = 2) +
  geom_line(aes(y = prediction_ale, group = 1, color = "ALE"), linewidth = 1) +
  geom_point(aes(y = prediction_ale, color = "ALE"), size = 2) +
  geom_line(aes(y = prediction_ice, group = 1, color = "ICE"), linewidth = 1) +
  geom_point(aes(y = prediction_ice, color = "ICE"), size = 2) +
  scale_fill_manual(name = "", values = c("Relative frequency" = "grey60")) +
  scale_color_manual(
    name = "Claim frequency (rate)",
    values = c("PDP" = "blue", "ALE" = "red", "ICE" = "green")
  ) +
  labs(
    title = "GBM – Age effect (PDP vs ALE vs ICE)",
    x = "",
    y = ""
  ) +
  theme_classic() +
  theme(plot.title = element_text(hjust = 0.5))

# -------------------------
# Save plot
# -------------------------
if (!dir.exists(DIR_OUTPUT_PLOTS)) dir.create(DIR_OUTPUT_PLOTS, recursive = TRUE)

plot(p)
#save_plot(p, "gbm_age_pdp_ale_ice.png")
save_png_plot(file.path(DIR_OUTPUT_PLOTS, "gbm_age_pdp_ale_ice.png"), p, 1200, 800)

cat("\n07_gbm_profiles_plots DONE\n")
cat("Saved: ", file.path(DIR_OUTPUT_PLOTS, "gbm_age_pdp_ale_ice.png"), "\n")
