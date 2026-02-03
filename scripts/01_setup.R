# =========================
# 01_setup.R  
# =========================

# --- Global seed ---
SEED <- 1
K_FOLDS <- 10
set.seed(SEED)

# --- Paths (relative to PROJECT ROOT) ---
DATA_PATH <- file.path("data", "raw", "claims_data.xlsx")

DIR_DATA_PROCESSED <- file.path("data", "processed")
DIR_OUTPUT_MODELS  <- file.path("output", "models")
DIR_OUTPUT_TABLES  <- file.path("output", "tables")
DIR_OUTPUT_PLOTS   <- file.path("output", "plots")

# --- Helpers ---
ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
}

ensure_dir(DIR_DATA_PROCESSED)
ensure_dir(DIR_OUTPUT_MODELS)
ensure_dir(DIR_OUTPUT_TABLES)
ensure_dir(DIR_OUTPUT_PLOTS)

# ----------------------------
# Plot saver 
# ----------------------------
save_plot <- function(plot_obj, filename, width = 10, height = 5, dpi = 300) {
  ensure_dir(DIR_OUTPUT_PLOTS)
  out <- file.path(DIR_OUTPUT_PLOTS, filename)
  
  ggplot2::ggsave(
    filename = out,
    plot = plot_obj,
    width = width,
    height = height,
    dpi = dpi,
    device = "png",
    bg = "white"
  )
  
  # Hard check: file exists & not tiny
  if (!file.exists(out)) stop("ggsave failed, file not found: ", out)
  sz <- file.info(out)$size
  if (is.na(sz) || sz < 5000) stop("Plot saved but looks empty/tiny (size < 5KB): ", out)
  
  message("Saved plot: ", normalizePath(out, winslash = "/", mustWork = FALSE))
  invisible(out)
}

save_png_plot <- function(filename, plot_obj, width = 1200, height = 800) {
  png(filename, width = width, height = height)
  print(plot_obj)   # <-- toto je kľúč
  dev.off()
}


# --- Package loader ---
load_packages <- function(pkgs) {
  installed <- rownames(installed.packages())
  to_install <- setdiff(pkgs, installed)
  if (length(to_install) > 0) {
    install.packages(to_install, dependencies = TRUE)
  }
  invisible(lapply(pkgs, library, character.only = TRUE))
}

# --- Packages used in pipeline ---
pkgs <- c(
  "readxl",
  "dplyr",
  "forcats",
  "caret",
  "MASS",
  "AER",
  "AICcmodavg",
  "randomForest",
  "gbm",
  "pscl",
  "DALEX",
  "DALEXtra",
  "ggplot2"
)

load_packages(pkgs)
rm(pkgs)

options(stringsAsFactors = FALSE)

#cat("01_setup.R loaded successfully\n")
#cat("SEED =", SEED, "| K_FOLDS =", K_FOLDS, "\n")
