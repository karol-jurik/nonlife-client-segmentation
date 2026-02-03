# =========================
# 03_feature_engineering.R
# =========================
source(file.path("scripts", "01_setup.R"))

data <- readRDS(file.path(DIR_DATA_PROCESSED, "data_base.rds"))

set.seed(SEED)

# --- 1) 80/20 split ONCE (holdout is sacred) ---
train_df <- data |> dplyr::sample_frac(0.8)
test_df  <- dplyr::anti_join(data, train_df, by = "ID")

# --- 2) Feature engineering functions (fit on train, apply to both) ---

fit_county_groups <- function(df_train) {
  # frequency per County (train only)
  county_fq <- df_train |>
    dplyr::group_by(County) |>
    dplyr::summarise(freq = sum(NClaims)/sum(Exposure), .groups = "drop")
  
  # same “hand-picked” thresholds as thesis for interpretability
  # A <= 0.065, B <= 0.095, C <= 0.14, else D
  county_map <- county_fq |>
    dplyr::mutate(
      G_County = dplyr::case_when(
        freq <= 0.065 ~ "A",
        freq <= 0.095 ~ "B",
        freq <= 0.14  ~ "C",
        TRUE          ~ "D"
      )
    ) |>
    dplyr::select(County, G_County)
  
  return(county_map)
}

apply_county_groups <- function(df, county_map) {
  out <- df |>
    dplyr::left_join(county_map, by = "County") |>
    dplyr::mutate(
      G_County = dplyr::if_else(is.na(G_County), "B", G_County),
      County = factor(G_County, levels = c("A","B","C","D"))
    ) |>
    dplyr::select(-G_County)
  return(out)
}

clean_and_impute_weight <- function(df_train, df_test) {
  # Fix obvious errors
  fix_weight <- function(x) {
    dplyr::if_else(x < 100 | x == 99999, as.numeric(NA), as.numeric(x))
  }
  
  df_train <- df_train |> dplyr::mutate(Weight = fix_weight(Weight))
  df_test  <- df_test  |> dplyr::mutate(Weight = fix_weight(Weight))
  
  # Train RF on train only (avoid leakage)
  train_obs <- df_train |> dplyr::filter(!is.na(Weight))
  
  # If everything is NA (unlikely), skip
  if (nrow(train_obs) < 100) {
    return(list(train = df_train, test = df_test))
  }
  
  rf <- randomForest::randomForest(
    Weight ~ EngPerfKW + CarAge + Make + Age,
    data = train_obs
  )
  
  # Predict missing in train
  miss_train <- which(is.na(df_train$Weight))
  if (length(miss_train) > 0) {
    df_train$Weight[miss_train] <- predict(rf, newdata = df_train[miss_train, ])
  }
  
  # Predict missing in test
  miss_test <- which(is.na(df_test$Weight))
  if (length(miss_test) > 0) {
    df_test$Weight[miss_test] <- predict(rf, newdata = df_test[miss_test, ])
  }
  
  return(list(train = df_train, test = df_test))
}

make_features <- function(df) {
  # Age groups (same as thesis code)
  df <- df |>
    dplyr::mutate(
      Age = cut(
        Age,
        breaks = c(0,25,35,45,55,65,Inf),
        labels = c("18-24","25-34","35-44","45-54","55-64","65+"),
        ordered_result = FALSE
      ),
      CarAge = cut(
        CarAge,
        breaks = c(-Inf,3,10,15,Inf),
        labels = c("0-3","4-10","11-15","16+"),
        ordered_result = FALSE
      ),
      EngPerfKW = cut(
        EngPerfKW,
        breaks = c(-Inf,60,100,150,Inf),
        labels = c("60-","61-100","101-150","150+"),
        ordered_result = FALSE
      ),
      Weight = cut(
        Weight,
        breaks = c(-Inf,1200,1600,2000,Inf),
        labels = c("1200-","1201-1600","1601-2000","2001+"),
        ordered_result = FALSE
      ),
      Make = factor(Make, ordered = FALSE)
    )
  
  return(df)
}

align_factor_levels <- function(train_df, test_df) {
  # Ensure test has same factor levels as train (critical)
  factor_cols <- names(train_df)[sapply(train_df, is.factor)]
  for (col in factor_cols) {
    test_df[[col]] <- factor(test_df[[col]], levels = levels(train_df[[col]]))
  }
  return(list(train = train_df, test = test_df))
}

# --- 3) Fit/Apply county groups (train only) ---
county_map <- fit_county_groups(train_df)
train_df <- apply_county_groups(train_df, county_map)
test_df  <- apply_county_groups(test_df,  county_map)

# --- 4) Weight cleaning + imputation (train only learns RF) ---
tmp <- clean_and_impute_weight(train_df, test_df)
train_df <- tmp$train
test_df  <- tmp$test
rm(tmp)

# --- 5) Make features (cuts to groups) ---
train_df <- make_features(train_df)
test_df  <- make_features(test_df)

# --- 6) Keep only modeling columns (same as thesis data_clean) ---
train_data <- train_df |>
  dplyr::select(
    ID, NClaims, Exposure,
    County, Age, Gender,
    EngPerfKW, Weight, Make, CarAge
  )

test_data <- test_df |>
  dplyr::select(
    ID, NClaims, Exposure,
    County, Age, Gender,
    EngPerfKW, Weight, Make, CarAge
  )

# --- 7) Align factor levels ---
aligned <- align_factor_levels(train_data, test_data)
train_data <- aligned$train
test_data  <- aligned$test
rm(aligned)

# Save
saveRDS(train_data, file.path(DIR_DATA_PROCESSED, "train_data.rds"))
saveRDS(test_data,  file.path(DIR_DATA_PROCESSED, "test_data.rds"))
saveRDS(county_map, file.path(DIR_DATA_PROCESSED, "county_map.rds"))

cat("03_feature_engineering DONE\n",
    "Train:", nrow(train_data), "rows\n",
    "Test :", nrow(test_data), "rows\n")
