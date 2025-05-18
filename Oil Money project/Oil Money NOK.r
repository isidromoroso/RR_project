# Oil Money NOK - R Translation

# Load required libraries
library(tidyverse)
library(lubridate)
library(glmnet)
library(dplyr)
library(ggplot2)
library(tidyr)
library(urca)
library(tseries)

# Load and prepare data
df <- read.csv("data/brent crude nokjpy.csv", check.names = FALSE)
colnames(df)[1] <- "date"
df$date <- as.Date(df$date, format = "%m/%d/%Y")

# Scatter plot NOK vs Brent
df %>%
  filter(date < as.Date("2018-04-24")) %>%
  ggplot(aes(x = brent, y = nok)) +
  geom_point(color = "#5f0f4e", size = 0.8) +
  labs(title = "NOK Brent Correlation", x = "Brent in JPY", y = "NOKJPY") +
  theme_minimal()

# Dual-axis base plot function (mimics Python twin axes)
dual_base_plot <- function(data, y1_col, y2_col, y1_label, y2_label, title,
                           col1 = "#34262b", col2 = "#cb2800") {
  # Set margins to allow right axis label
  par(mar = c(5, 4, 4, 4) + 0.1)
  # Plot first series
  plot(data$date, data[[y1_col]], type = "l", col = col1,
       xlab = "Date", ylab = y1_label, main = title)
  # Overlay second series with no axes
  par(new = TRUE)
  plot(data$date, data[[y2_col]], type = "l", col = col2,
       axes = FALSE, xlab = "", ylab = "")
  axis(side = 4, col = col2, col.axis = col2)
  mtext(y2_label, side = 4, line = 3, col = col2)
  legend("bottomright", legend = c(y1_label, y2_label),
         col = c(col1, col2), lty = 1, bty = "n")
}

# Use dual_base_plot for relationships
# NOK vs Interest Rate
dual_base_plot(
  df %>% filter(date < as.Date("2018-04-24")),
  y1_col = "nok", y2_col = "interest rate",
  y1_label = "NOKJPY", y2_label = "Interest Rate",
  title = "NOK vs Interest Rate"
)

# NOK vs Brent
dual_base_plot(
  df %>% filter(date < as.Date("2018-04-24")),
  y1_col = "nok", y2_col = "brent",
  y1_label = "NOKJPY", y2_label = "Brent in JPY",
  title = "NOK vs Brent",
  col2 = "#66ffff"
)

# NOK vs GDP (quarterly) 

# Get indices and values where quarterly GDP is available
gdp_idx    <- which(!is.na(df$`gdp yoy`))
gdp_dates  <- df$date[gdp_idx]
gdp_values <- df$`gdp yoy`[gdp_idx]
nok_values <- df$nok[gdp_idx]  # Get actual NOK values on the same GDP dates

# Prepare combined dataframe with matched frequency
gdp_plot_df <- data.frame(
  date = gdp_dates,
  nok = nok_values,
  gdp_yoy = gdp_values
) %>% filter(date < as.Date("2018-01-01"))

# Plot using dual_base_plot
dual_base_plot(
  gdp_plot_df,
  y1_col = "nok", y2_col = "gdp_yoy",
  y1_label = "NOKJPY", y2_label = "GDP YoY %",
  title = "NOK vs GDP"
)

# Linear regression (OLS)
x0 <- df %>% select(usd, gbp, eur, brent)
y  <- df$nok
train_idx <- df$date < as.Date("2017-04-25")
ols_model <- lm(y[train_idx] ~ ., data = x0[train_idx, ])
print(summary(ols_model))

#Elastic Net regression (glmnet)
# Define the cutoff date
cutoff_date <- as.Date("2017-04-25")

# Filter data before the cutoff date
x0_filtered <- as.matrix(df[df$date < cutoff_date, c("usd", "gbp", "eur", "brent")])
y_filtered <- df$nok[df$date < cutoff_date]

# Parameters to evaluate
l1_ratio <- 0.01  # alpha in glmnet (Python l1_ratio)
lambdas <- c(9.9999, 10, 10.0000001)  # lambda in glmnet, I set closest to the 10 because is the best value in Python (Python alpha) 

# Search for the best model
best_model <- NULL
best_mse <- Inf
best_alpha <- NA
best_lambda <- NA

set.seed(123)  # For reproducibility
fit <- cv.glmnet(
  x = x0_filtered,
  y = y_filtered,
  alpha = l1_ratio,
  lambda = lambdas,
  standardize = FALSE,  # <-- Avoid standardization (Python Elastic Net doesn't apply standardization)
  intercept = TRUE,
  nfolds = 5,
  maxit = 5000
)

if (min(fit$cvm) < best_mse) {
  best_mse <- min(fit$cvm)
  best_model <- fit
  best_alpha <- l1_ratio
  best_lambda <- fit$lambda.min
}

# Extract coefficients
coef_best <- coef(best_model, s = "lambda.min")
intercept <- coef_best[1]
coefs <- as.vector(coef_best[-1])

cat("Best alpha (l1_ratio):", best_alpha, "\n")
cat("Best lambda:", best_lambda, "\n")
cat("Intercept:", intercept, "\n")
cat("Coefficients:", round(coefs, 5), "\n")

# Compute fitted values and residuals for the full dataframe
df$sk_fit <- df$usd * coefs[1] +
  df$gbp * coefs[2] +
  df$eur * coefs[3] +
  df$brent * coefs[4] +
  intercept

df$sk_residual <- df$nok - df$sk_fit

# Signals generation logic
# Set thresholds based on 1 sigma of residuals before the cutoff date
residual_std <- sd(df$sk_residual[df$date < as.Date('2017-04-25')])
upper <- residual_std
lower <- -residual_std

# Create the signals dataframe starting from April 25, 2017
signals <- df %>%
  filter(date >= as.Date('2017-04-25')) %>%
  select(date, nok, usd, eur, gbp, brent, sk_fit, sk_residual)

# Rename 'sk_fit' column to 'fitted'
signals <- signals %>%
  rename(fitted = sk_fit)

# Add band levels and initialize signal columns
signals <- signals %>%
  mutate(
    stop_profit = fitted + 2 * upper,
    stop_loss = fitted + 2 * lower,
    upper = fitted + upper,
    lower = fitted + lower,
    signals = 0
  )

# Ensure signals dataframe has signal and cumulative signal columns
signals$signals <- 0
signals$cumsum <- 0  # to track cumulative signal exposure

# Loop row by row
for (j in 1:nrow(signals)) {
  
  # Entry rules
  if (signals$nok[j] > signals$upper[j]) {
    signals$signals[j] <- -1  # Short signal
  }
  
  if (signals$nok[j] < signals$lower[j]) {
    signals$signals[j] <- 1   # Long signal
  }
  
  # Recalculate cumulative signal count
  signals$cumsum <- cumsum(signals$signals)
  
  # Neutralize if cumulative exposure exceeds ±1
  if (signals$cumsum[j] > 1 || signals$cumsum[j] < -1) {
    signals$signals[j] <- 0
    #signals$cumsum <- cumsum(signals$signals)
  }
  
  # STOP PROFIT: if profit limit is reached
  if (signals$nok[j] > signals$stop_profit[j]) {
    signals$cumsum <- cumsum(signals$signals)
    signals$signals[j] <- -signals$cumsum[j] + 1
    signals$cumsum <- cumsum(signals$signals)
    break  # stop algorithm
  }
  
  # STOP LOSS: if loss limit is reached
  if (signals$nok[j] < signals$stop_loss[j]) {
    signals$cumsum <- cumsum(signals$signals)
    signals$signals[j] <- -signals$cumsum[j] - 1
    signals$cumsum <- cumsum(signals$signals)
    break  # stop algorithm
  }
}




