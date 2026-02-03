# =========================
# 05_gbm_models.R
# =========================
source(file.path("scripts", "01_setup.R"))

# Load data
train_data <- readRDS(file.path(DIR_DATA_PROCESSED, "train_data.rds"))
test_data  <- readRDS(file.path(DIR_DATA_PROCESSED, "test_data.rds"))

set.seed(SEED)

# -------------------------
# Keep factor levels stable
# (important for Make etc.)
# -------------------------
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

# -------------------------
# GBM formula (like thesis)
# -------------------------
# Same logic as your thesis GBM: exclude Gender, keep offset(log(Exposure))
predictors_gbm <- c("County", "Age", "Weight", "CarAge", "Make", "EngPerfKW")

missing_cols <- setdiff(c("NClaims", "Exposure", predictors_gbm), names(train_data))
if (length(missing_cols) > 0) {
  stop("Missing columns in train_data: ", paste(missing_cols, collapse = ", "))
}

formula_gbm <- stats::as.formula(
  paste0("NClaims ~ offset(log(Exposure)) + ", paste(predictors_gbm, collapse = " + "))
)

# -------------------------
# Parameter grid
# (around thesis defaults)
# -------------------------
param_grid <- expand.grid(
  n.trees = c(70, 100),
  interaction.depth = c(4, 5),
  shrinkage = c(0.05, 0.01),
  bag.fraction = c(0.5, 0.7),
  n.minobsinnode = c(10, 20)
)

if (!dir.exists(DIR_OUTPUT_TABLES)) dir.create(DIR_OUTPUT_TABLES, recursive = TRUE)
if (!dir.exists(DIR_OUTPUT_MODELS)) dir.create(DIR_OUTPUT_MODELS, recursive = TRUE)

# -------------------------
# Fit one GBM with CV
# -------------------------
fit_gbm_cv <- function(train_df, formula, params, k_folds = 10, seed = SEED) {
  set.seed(seed)
  
  fit <- gbm::gbm(
    formula = formula,
    data = train_df,
    distribution = "poisson",
    n.trees = params$n.trees,
    interaction.depth = params$interaction.depth,
    shrinkage = params$shrinkage,
    bag.fraction = params$bag.fraction,
    n.minobsinnode = params$n.minobsinnode,
    cv.folds = k_folds,
    verbose = FALSE
  )
  
  best_iter <- gbm::gbm.perf(fit, method = "cv", plot.it = FALSE)
  cv_err <- fit$cv.error[best_iter]
  
  list(fit = fit, best_iter = best_iter, cv_error = cv_err)
}

# -------------------------
# Grid search (CV on TRAIN)
# -------------------------
cat("Running GBM grid search (CV on TRAIN)...\n")
cat("Grid size:", nrow(param_grid), "models\n\n")

grid_results <- data.frame()
best_cv <- Inf
best_params <- NULL
best_iter <- NA
best_fit <- NULL

failed_count <- 0L
progress_every <- 5L

start_time <- Sys.time()

for (i in seq_len(nrow(param_grid))) {
  params <- param_grid[i, ]
  
  #cat("Model", i, "/", nrow(param_grid),
  #    "| trees:", params$n.trees,
  #    "depth:", params$interaction.depth,
  #    "shrink:", params$shrinkage,
  #    "bag:", params$bag.fraction,
  #    "minobs:", params$n.minobsinnode, "\n")
  
  res <- tryCatch(
    fit_gbm_cv(train_data, formula_gbm, params, k_folds = K_FOLDS, seed = SEED),
    error = function(e) NULL
  )
  
  if (is.null(res)) {
    failed_count <- failed_count + 1L
    next
  }
  
  row <- data.frame(
    n.trees = params$n.trees,
    interaction.depth = params$interaction.depth,
    shrinkage = params$shrinkage,
    bag.fraction = params$bag.fraction,
    n.minobsinnode = params$n.minobsinnode,
    best_iter = res$best_iter,
    cv_error = res$cv_error
  )
  
  grid_results <- dplyr::bind_rows(grid_results, row)
  
  #cat("  -> best_iter:", res$best_iter, "| cv_error:", round(res$cv_error, 6), "\n\n")
  
  if (!is.na(res$cv_error) && res$cv_error < best_cv) {
    best_cv <- res$cv_error
    best_fit <- res$fit
    best_iter <- res$best_iter
    best_params <- params
  }


  # ---- PROGRESS + ETA ----
  if (i %% progress_every == 0L || i == nrow(param_grid)) {
    elapsed_sec <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    avg_sec_per_model <- elapsed_sec / i
    remaining_sec <- avg_sec_per_model * (nrow(param_grid) - i)
    
    cat(sprintf(
      "Progress: %d/%d | elapsed: %.1fs | ETA: %.1fs | best_cv: %.6f\n",
      i, nrow(param_grid), elapsed_sec, remaining_sec, best_cv
    ))
  }
}

write.csv(grid_results, file.path(DIR_OUTPUT_TABLES, "gbm_grid_results.csv"), row.names = FALSE)

cat("\nDONE.\n")
cat("Failed fits:", failed_count, "\n")
cat("Best CV error:", best_cv, "\n")
cat("Best params:\n"); print(best_params)
cat("Best iter:", best_iter, "\n\n")

if (is.null(best_params)) stop("All GBM fits failed. Check data / packages / formula.")

# -------------------------
# Refit final GBM on TRAIN
# -------------------------
cat("Fitting final GBM on full TRAIN with best params...\n")
set.seed(SEED)

gbm_final <- gbm::gbm(
  formula = formula_gbm,
  data = train_data,
  distribution = "poisson",
  n.trees = best_params$n.trees,
  interaction.depth = best_params$interaction.depth,
  shrinkage = best_params$shrinkage,
  bag.fraction = best_params$bag.fraction,
  n.minobsinnode = best_params$n.minobsinnode,
  cv.folds = K_FOLDS,
  verbose = FALSE
)

best_iter_final <- gbm::gbm.perf(gbm_final, method = "cv", plot.it = FALSE)

# -------------------------
# Holdout evaluation (TEST)
# -------------------------
pred_test <- predict(gbm_final, newdata = test_data, n.trees = best_iter_final, type = "response")
mse_test <- mean((test_data$NClaims - pred_test)^2)

holdout <- data.frame(
  Model = "GBM_poisson",
  best_iter = best_iter_final,
  cv_error = gbm_final$cv.error[best_iter_final],
  MSE_test = mse_test
)

write.csv(holdout, file.path(DIR_OUTPUT_TABLES, "gbm_holdout_results.csv"), row.names = FALSE)
print(holdout)

# Variable importance (gbm internal)
varimp <- as.data.frame(gbm::summary.gbm(gbm_final, n.trees = best_iter_final, plotit = FALSE))
write.csv(varimp, file.path(DIR_OUTPUT_TABLES, "gbm_variable_importance.csv"), row.names = FALSE)

# Save model + metadata (IMPORTANT for SHAP later)
gbm_bundle <- list(
  model = gbm_final,
  best_iter = best_iter_final,
  formula = formula_gbm,
  predictors = predictors_gbm,
  params = best_params,
  seed = SEED,
  k_folds = K_FOLDS
)

saveRDS(gbm_bundle, file.path(DIR_OUTPUT_MODELS, "gbm_poisson_best.rds"))

cat("\n05_gbm_models DONE\n")
