# =========================
# 04_glm_models.R
# =========================
source(file.path("scripts", "01_setup.R"))

# ---- Load train/test from 03 ----
train_data <- readRDS(file.path(DIR_DATA_PROCESSED, "train_data.rds"))
test_data  <- readRDS(file.path(DIR_DATA_PROCESSED, "test_data.rds"))

# Ensure output dirs exist
dir.create(DIR_OUTPUT_TABLES, showWarnings = FALSE, recursive = TRUE)
dir.create(DIR_OUTPUT_MODELS, showWarnings = FALSE, recursive = TRUE)

# -------------------------
# Helpers
# -------------------------

# Convert formula / string safely to ONE string (no length>1 character vectors)
as_formula_string <- function(x) {
  if (inherits(x, "formula")) {
    return(paste(deparse(x), collapse = " "))
  }
  stopifnot(is.character(x), length(x) == 1)
  x
}

# Make folds (train indices) - simple and stable
make_folds <- function(y, k = 10, seed = SEED) {
  set.seed(seed)
  caret::createFolds(y, k = k, list = TRUE, returnTrain = TRUE)
}

# Keep factor levels stable across folds (important for Make/County/etc.)
freeze_factor_levels <- function(df) {
  factor_cols <- names(df)[sapply(df, is.factor)]
  lvl <- lapply(df[factor_cols], levels)
  list(factor_cols = factor_cols, levels = lvl)
}

apply_factor_levels <- function(df, frozen) {
  for (nm in frozen$factor_cols) {
    df[[nm]] <- factor(df[[nm]], levels = frozen$levels[[nm]])
  }
  df
}

# -------------------------
# CV: Poisson / NegBin
# -------------------------
cv_glm <- function(data, formula, response = "NClaims",
                   k = 10, seed = SEED, type = c("poisson", "nb")) {
  
  type <- match.arg(type)
  fml  <- stats::as.formula(as_formula_string(formula))
  
  folds <- make_folds(data[[response]], k = k, seed = seed)
  
  dev_vec <- c()
  ll_vec  <- c()
  aic_vec <- c()
  bic_vec <- c()
  mse_vec <- c()
  
  for (i in seq_along(folds)) {
    idx_train <- folds[[i]]
    d_train <- data[idx_train, , drop = FALSE]
    d_test  <- data[-idx_train, , drop = FALSE]
    
    fit <- tryCatch({
      if (type == "poisson") {
        stats::glm(fml, data = d_train, family = poisson(link = "log"))
      } else {
        MASS::glm.nb(fml, data = d_train, link = "log")
      }
    }, error = function(e) NULL)
    
    if (is.null(fit)) next
    
    preds <- tryCatch(
      stats::predict(fit, newdata = d_test, type = "response"),
      error = function(e) NULL
    )
    if (is.null(preds)) next
    
    dev_vec <- c(dev_vec, stats::deviance(fit))
    ll_vec  <- c(ll_vec,  as.numeric(stats::logLik(fit)))
    aic_vec <- c(aic_vec, stats::AIC(fit))
    bic_vec <- c(bic_vec, stats::BIC(fit))
    mse_vec <- c(mse_vec, mean((d_test[[response]] - preds)^2))
  }
  
  data.frame(
    Model    = ifelse(type == "poisson", "Poisson", "NegBin"),
    LogLik   = mean(ll_vec,  na.rm = TRUE),
    Deviance = mean(dev_vec, na.rm = TRUE),
    AIC      = mean(aic_vec, na.rm = TRUE),
    BIC      = mean(bic_vec, na.rm = TRUE),
    MSE      = mean(mse_vec, na.rm = TRUE)
  )
}

# -------------------------
# CV: ZIP (PSCL zeroinfl)
#    count_part | offset(log(Exposure))
# -------------------------
cv_zip <- function(data, formula, response = "NClaims",
                          k = 10, seed = SEED, dist = "poisson") {
  
  # Your original expects a string; we accept both string/formula safely
  count_str <- as_formula_string(formula)
  
  # IMPORTANT:
  # - formula must be exactly "count ~ ... | zero"
  # - DO NOT use se.fit in predict() for zeroinfl
  full_str <- paste0(count_str, " | offset(log(Exposure))")
  full_fml <- stats::as.formula(full_str)
  
  folds <- make_folds(data[[response]], k = k, seed = seed)
  
  # freeze factor levels for stability
  frozen <- freeze_factor_levels(data)
  
  ll_vec  <- c()
  aic_vec <- c()
  bic_vec <- c()
  mse_vec <- c()
  
  failed <- 0L
  
  for (i in seq_along(folds)) {
    idx_train <- folds[[i]]
    
    d_train <- apply_factor_levels(data[idx_train, , drop = FALSE], frozen)
    d_test  <- apply_factor_levels(data[-idx_train, , drop = FALSE], frozen)
    
    fit <- tryCatch(
      pscl::zeroinfl(
        formula = full_fml,
        data    = d_train,
        dist    = dist,
        control = pscl::zeroinfl.control(maxit = 200)
      ),
      error = function(e) NULL
    )
    
    if (is.null(fit)) {
      failed <- failed + 1L
      next
    }
    
    preds <- tryCatch(
      stats::predict(fit, newdata = d_test, type = "response"),
      error = function(e) rep(NA_real_, nrow(d_test))
    )
    
    y <- d_test[[response]]
    
    ll_vec  <- c(ll_vec,  as.numeric(stats::logLik(fit)))
    aic_vec <- c(aic_vec, stats::AIC(fit))
    bic_vec <- c(bic_vec, stats::BIC(fit))
    mse_vec <- c(mse_vec, mean((y - preds)^2, na.rm = TRUE))
  }
  
  out <- data.frame(
    Model    = "ZIP",
    LogLik   = ifelse(length(ll_vec)  > 0, mean(ll_vec,  na.rm = TRUE), NA_real_),
    Deviance = NA_real_,  # deviance is not reliable/consistent for zeroinfl -> keep NA
    AIC      = ifelse(length(aic_vec) > 0, mean(aic_vec, na.rm = TRUE), NA_real_),
    BIC      = ifelse(length(bic_vec) > 0, mean(bic_vec, na.rm = TRUE), NA_real_),
    MSE      = ifelse(length(mse_vec) > 0, mean(mse_vec, na.rm = TRUE), NA_real_)
  )
  
  attr(out, "zip_formula") <- full_str
  attr(out, "failed_folds") <- failed
  attr(out, "k") <- length(folds)
  
  out
}

# -------------------------
# Formulas (match thesis logic)
# -------------------------

# Thesis-best (most used in your work)
formula_glm_best <- stats::as.formula(
  "NClaims ~ offset(log(Exposure)) + County + Age + Weight + CarAge"
)

# Full model (optional)
formula_glm_full <- stats::as.formula(
  "NClaims ~ offset(log(Exposure)) + County + Age + Gender + EngPerfKW + Weight + Make + CarAge"
)

# For ZIP CV we pass STRING (exactly like your thesis code)
formula_zip_best_str <- "NClaims ~ offset(log(Exposure)) + County + Age + Weight + CarAge"

# -------------------------
# 1) CV on TRAIN (10-fold)
# -------------------------
set.seed(SEED)

cv_res <- dplyr::bind_rows(
  cv_glm(train_data, formula_glm_best, k = K_FOLDS, seed = SEED, type = "poisson"),
  cv_glm(train_data, formula_glm_best, k = K_FOLDS, seed = SEED, type = "nb"),
  cv_zip(train_data, formula_zip_best_str, k = K_FOLDS, seed = SEED, dist = "poisson")
)

write.csv(cv_res, file.path(DIR_OUTPUT_TABLES, "glm_cv_results.csv"), row.names = FALSE)
print(cv_res)

# -------------------------
# 2) Fit final models on FULL TRAIN
# -------------------------
fit_pois <- stats::glm(formula_glm_best, data = train_data, family = poisson(link = "log"))
fit_nb   <- MASS::glm.nb(formula_glm_best, data = train_data, link = "log")

# IMPORTANT: correct ZIP formula (your earlier script had missing ')')
fit_zip <- pscl::zeroinfl(
  formula = stats::as.formula(
    "NClaims ~ offset(log(Exposure)) + County + Age + Weight + CarAge | offset(log(Exposure))"
  ),
  data = train_data,
  dist = "poisson",
  control = pscl::zeroinfl.control(maxit = 200)
)

saveRDS(fit_pois, file.path(DIR_OUTPUT_MODELS, "glm_poisson_best.rds"))
saveRDS(fit_nb,   file.path(DIR_OUTPUT_MODELS, "glm_negbin_best.rds"))
saveRDS(fit_zip,  file.path(DIR_OUTPUT_MODELS, "glm_zip_best.rds"))

# -------------------------
# 3) Holdout evaluation (TEST only, no tuning)
# -------------------------
eval_holdout_mse <- function(model, test_df, response = "NClaims") {
  preds <- stats::predict(model, newdata = test_df, type = "response")
  mean((test_df[[response]] - preds)^2)
}

holdout <- data.frame(
  Model = c("Poisson_best", "NegBin_best", "ZIP_best"),
  MSE = c(
    eval_holdout_mse(fit_pois, test_data),
    eval_holdout_mse(fit_nb,   test_data),
    eval_holdout_mse(fit_zip,  test_data)
  )
)

write.csv(holdout, file.path(DIR_OUTPUT_TABLES, "glm_holdout_results.csv"), row.names = FALSE)
print(holdout)

# -------------------------
# 4) Optional diagnostics (quick)
# -------------------------
cat("\nDispersion test (Poisson):\n")
print(AER::dispersiontest(fit_pois, alternative = "greater"))

cat("\nVuong test (Poisson vs ZIP):\n")
pscl::vuong(fit_pois, fit_zip)

cat("\n04_glm_models DONE\n")
