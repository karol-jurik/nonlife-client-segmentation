# =========================
# 02_import_clean.R
# =========================
source(file.path("scripts", "01_setup.R"))

# 1) Load raw data
data_raw <- readxl::read_excel(DATA_PATH)

# 2) Drop columns you didn't use in thesis (same logic)
data <- data_raw |>
  dplyr::select(
    -c(
      "ValidFrom",
      "ValidThru",
      "EarnedPremium",
      "YearlyNetPremium",
      "ClaimNr",
      "ClaimDate",
      "ClaimYear",
      "Incurred",
      "Payments",
      "Reserve",
      "ConstrYear",
      "ClaimReason",
      "BonusMalus",
      "G_EngPerfKW",
      "G_Weight",
      "G_Age"
    )
  )

# 3) Aggregate across years (same logic)
# NOTE: you did: group_by(ContractNr, Make, CarAge, EngPerfKW), sum NClaims/Exposure
data <- data |>
  dplyr::group_by(ContractNr, Make, CarAge, EngPerfKW) |>
  dplyr::mutate(
    NClaims = sum(NClaims, na.rm = TRUE),
    Exposure = sum(Exposure, na.rm = TRUE)
  ) |>
  dplyr::ungroup()

# 4) Remove duplicates (same logic)
data <- data[!duplicated(data), ]

# Keep first occurrence by Year (same logic)
if ("Year" %in% names(data)) {
  data <- data |>
    dplyr::group_by(ContractNr, Make, CarAge, EngPerfKW) |>
    dplyr::slice_min(Year, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::select(-Year)
}

# 5) Remove missing County
data <- data |>
  dplyr::filter(!is.na(County))

# 6) Filter out very short policies (Exposure < 14 days)
data <- data |>
  dplyr::filter(Exposure >= 14/365)

# 7) Gender recode (same logic) + drop X/Other
if ("Gender" %in% names(data)) {
  data <- data |>
    dplyr::mutate(
      Gender = dplyr::if_else(Gender == "male", "M",
                              dplyr::if_else(Gender == "female", "F", "X"))
    ) |>
    dplyr::filter(Gender != "X") |>
    dplyr::mutate(Gender = factor(Gender, levels = c("F", "M"),
                                  labels = c("Female", "Male")))
}

# 8) Create ID and drop ContractNr (same logic)
data <- data |>
  dplyr::mutate(ID = dplyr::row_number()) |>
  dplyr::select(-ContractNr)

# 9) Basic sanity checks
stopifnot(all(!is.na(data$NClaims)))
stopifnot(all(!is.na(data$Exposure)))
stopifnot(nrow(data) > 1000)

# Save
saveRDS(data_raw, file.path(DIR_DATA_PROCESSED, "data_raw.rds"))
saveRDS(data,     file.path(DIR_DATA_PROCESSED, "data_base.rds"))

cat("02_import_clean DONE\n",
    "Rows:", nrow(data), "\n",
    "Columns:", ncol(data), "\n")
