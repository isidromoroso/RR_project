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
library(tidyverse)

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

# Ensure the 'date' column is of class Date
signals$date <- as.Date(signals$date)

# Create dataframes for LONG, SHORT, and Exit Point signals
long_signals <- signals %>%
  filter(signals > 0)

short_signals <- signals %>%
  filter(signals < 0)

exit_point <- signals %>%
  filter(date == as.Date("2017-12-20"))

# NOK signals positions plot
ggplot(signals, aes(x = date, y = nok)) +
  geom_line(color = "#594f4f", alpha = 0.5) +
  geom_point(data = long_signals, aes(x = date, y = nok),
             color = "#83af9b", shape = 24, fill = "#83af9b", size = 4) +
  geom_point(data = short_signals, aes(x = date, y = nok),
             color = "#fe4365", shape = 25, fill = "#fe4365", size = 4) +
  geom_point(data = exit_point, aes(x = date, y = nok),
             color = "#f9d423", shape = 8, size = 5, alpha = 0.8) +
  geom_vline(xintercept = as.Date("2017-11-15"), linetype = "dotted", color = "black") +
  labs(title = "NOKJPY Positions",
       x = "Date",
       y = "NOKJPY") +
  theme_minimal() +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(color = "gray90"),
        axis.title = element_text(face = "bold"),
        legend.position = "none")

# Fitted vs Actual plot
ggplot(signals, aes(x = date)) +
  geom_line(aes(y = fitted), color = "white", size = 1.2, alpha = 0.6) +
  geom_line(aes(y = nok), color = "black", size = 1.1, alpha = 0.8) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = "#2a3457", alpha = 0.2) +
  geom_ribbon(aes(ymin = stop_loss, ymax = stop_profit), fill = "#720017", alpha = 0.1) +
  labs(title = "Fitted vs Actual", x = "Date", y = "NOKJPY") +
  theme_minimal()

# Normalized price trend plot 
# Normalize prices by dividing each by its first value and multiplying by 100
df_norm <- df %>%
  mutate(across(c(nok, usd, eur, gbp, brent), ~ . / .[1] * 100)) %>%
  select(date, nok, usd, eur, gbp, brent) %>%
  pivot_longer(cols = -date, names_to = "currency", values_to = "value")

# Custom colors
color_map <- c(
  nok   = "#ff8c94",  # Norwegian Krone
  usd   = "#9de0ad",  # US Dollar
  eur   = "#45ada8",  # Euro
  gbp   = "#f8b195",  # UK Sterling
  brent = "#6c5b7c"   # Brent Crude
)

# Custom labels for legend
label_map <- c(
  nok   = "Norwegian Krone",
  usd   = "US Dollar",
  eur   = "Euro",
  gbp   = "UK Sterling",
  brent = "Brent Crude"
)

# Create plot
ggplot(df_norm, aes(x = date, y = value, color = currency)) +
  geom_line(alpha = 0.9) +
  scale_color_manual(
    values = color_map,
    labels = label_map
  ) +
  labs(
    title = "Trend",
    x = "Date",
    y = "Normalized Price (Base = 100)",
    color = "Asset"
  ) +
  theme_minimal() +
  theme(
    panel.grid.minor = element_blank(),
    axis.title = element_text(face = "bold"),
    legend.position = "right"  # Puedes cambiar a "bottom", "left", etc.
  )

# Cointegration analysis
# Define the cutoff date
cutoff_date <- as.Date("2017-04-25")

# x2 is the predictor (eur), y is the dependent variable (nok)
x2 <- df$eur[df$date < cutoff_date]
y  <- df$nok[df$date < cutoff_date]

# OLS regression with intercept
ols_model <- lm(y ~ x2)
residuals <- resid(ols_model)

# ADF test on the residuals
adf_test <- ur.df(residuals, type = "none", selectlags = "AIC")
summary(adf_test)

# Show summary of the OLS regression
summary(ols_model)

# Performance analysis of signals strategy (Initial capital 2000, position size 100)
# Perform PnL (Profit and Loss) analysis
initial_capital <- 2000
position_size <- 100

# Create portfolio dataframe using the same index as signals
portfolio <- data.frame(date = signals$date)
rownames(portfolio) <- signals$date

# Calculate holding value: NOK price × cumulative position × position size
portfolio$holding <- signals$nok * signals$cumsum * position_size

# Calculate cash position: initial capital - cumulative cost of trades
portfolio$cash <- initial_capital - cumsum(signals$nok * signals$signals * position_size)

# Total asset value = holding + cash
portfolio$total_asset <- portfolio$holding + portfolio$cash

# Store signals for reference
portfolio$signals <- signals$signals

# Filter portfolio between 2017-10-01 and 2018-01-01
portfolio <- portfolio[portfolio$date > as.Date("2017-10-01") & portfolio$date < as.Date("2018-01-01"), ]

# Ensure 'date' column is of Date type
portfolio$date <- as.Date(portfolio$date)

# Compute standard deviation of total asset
asset_sd <- sd(portfolio$total_asset, na.rm = TRUE)

# Create subset for shaded region between 2017-11-20 and 2017-12-20
highlight_range <- portfolio %>%
  filter(date >= as.Date("2017-11-20") & date <= as.Date("2017-12-20")) %>%
  mutate(upper = total_asset + asset_sd,
         lower = total_asset - asset_sd)

# Create subsets for LONG and SHORT signal markers
longs <- portfolio %>% filter(signals > 0)
shorts <- portfolio %>% filter(signals < 0)

# Plot portfolio performance
ggplot(portfolio, aes(x = date, y = total_asset)) +
  geom_line(color = "#594f4f", alpha = 0.5, size = 0.7) +
  geom_point(data = longs, aes(x = date, y = total_asset),
             shape = 24, color = "#2a3457", fill = "#2a3457", size = 4, alpha = 0.5) +
  geom_point(data = shorts, aes(x = date, y = total_asset),
             shape = 25, color = "#720017", fill = "#720017", size = 6, alpha = 0.5) +
  geom_ribbon(data = highlight_range, aes(ymin = lower, ymax = upper),
              fill = "#547980", alpha = 0.2) +
  geom_vline(xintercept = as.Date("2017-11-15"), linetype = "dotted", color = "#ff847c") +
  annotate("text", x = as.Date("2017-12-20"),
           y = highlight_range$total_asset[highlight_range$date == as.Date("2017-12-20")] + asset_sd,
           label = "What if we use MACD here?", hjust = 0, size = 3.5) +
  labs(title = "Portfolio Performance",
       x = "Date", y = "Asset Value") +
  theme_minimal() +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(color = "gray90"),
        axis.title = element_text(face = "bold"),
        legend.position = "none")

# Oil_money_trading_backtest improved trading strategy optimised with gridsearch
# Import and run backtest module
source("oil_money_trading_backtest.r")
portfolio_data <- df %>% filter(date >= as.Date("2014-10-23"), date <= as.Date("2015-08-20"))
signals_bt   <- signal_generation(portfolio_data, "brent", "nok", oil_money)
portfolio_bt <- portfolio(signals_bt, "nok")
portfolio_bt$date <- portfolio_data$date
plot_signals(signals_bt, "nok")
graph_profit(portfolio_bt, "nok")

# Grid search for parameters
results <- expand.grid(h = 5:19, s = seq(0.3, 1.05, 0.05)) %>%
  mutate(return = map2_dbl(h, s, ~{
    sig <- signal_generation(df, "brent", "nok", oil_money, holding_threshold = .x, stop = .y)
    port <- portfolio(sig, "nok")
    tail(port$asset, 1) / head(port$asset, 1) - 1
  }))

# Trading returns distribution histogram (on NOK)
ggplot(results, aes(x = return * 100)) +
  geom_histogram(binwidth = 0.50, fill = "#f09e8c", color = "white") +
  labs(title = "Distribution of Return on NOK Trading", x = "Return (%)", y = "Frequency") +
  theme_minimal()

# Heatmap of returns changing Stop Profit/Loss and Holding Period
# Prepare data
return_df <- results %>%
  mutate(h = as.factor(h), s = as.factor(s)) %>%
  mutate(return = return * 100)  # convert to percentage

# Reverse factor levels of h (to invert y-axis)
return_df$h <- fct_rev(return_df$h)

# Plot
ggplot(return_df, aes(x = s, y = h, fill = return)) +
  geom_tile(color = NA) +  # no tile border
  scale_fill_gradientn(
    colors = c("#FFFFFF", "#ff8000", "#e63900", "#b30000", "#600000", "#000000"),
    name = "Return (%)",
    guide = guide_colorbar(
      direction = "vertical", 
      barwidth = 1, 
      barheight = 10,
      title.position = "top"
    )
  ) +
  coord_fixed() +  # makes tiles square
  labs(
    x = "Stop Profit/Loss",
    y = "Holding Period (days)",
    title = "Heatmap of Returns (%)"
  ) +
  theme_minimal(base_size = 15) +
  theme(
    panel.grid = element_blank(),           # remove grid
    legend.position = "right",              # legend on right
    legend.title.align = 0.5,               # center title
    legend.title = element_text(size = 10), # smaller title
    legend.text = element_text(size = 9),   # smaller labels
    axis.text.x = element_text(angle = 45, hjust = 1)
  )



