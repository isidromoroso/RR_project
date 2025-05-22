# ==== Load Required Libraries ====
# install.packages(c("ggplot2", "dplyr", "readr", "lubridate", "broom", "tidyr", "reshape2", "rsample", "viridis", "pheatmap", "scales"))

library(ggplot2)
library(dplyr)
library(readr)
library(lubridate)
library(broom)
library(tidyr)
library(reshape2)
library(rsample)
library(viridis)
library(pheatmap)
library(scales)
library(purrr)
library(dplyr)


graphics.off()

# ==== Load and Clean Data ====
data_path <- "data/vas crude copaud.csv"
df <- read_csv(data_path, show_col_types = FALSE)
df$date <- parse_date_time(df$date, orders = c("ymd", "mdy", "dmy"))
df <- df %>% filter(!is.na(date)) %>% arrange(date)

# ==== Output Folder ====
out_folder <- "COP Data/r_graphs_original"
dir.create(out_folder, recursive = TRUE, showWarnings = FALSE)

save_plot <- function(filename) {
  ggsave(file.path(out_folder, filename), dpi = 300, width = 10, height = 5)
}
summary(df$mxn)
# ==== Figure 1: R-squared Bar Chart ====
r2_results <- df %>%
  select(-date, -cop) %>%
  summarise(across(everything(), ~ summary(lm(df$cop ~ .x))$r.squared)) %>%
  pivot_longer(cols = everything(), names_to = "variable", values_to = "r2") %>%
  arrange(desc(r2))

fill_colors <- c(
  "wti"      = "#447294",
  "brent"    = "#8fbcdb",
  "vasconia" = "#f4d6bc"
)

other_vars <- setdiff(unique(r2_results$variable), names(fill_colors))
fill_colors <- c(fill_colors, setNames(rep("#cdc8c8", length(other_vars)), other_vars))

fig1 <- ggplot(r2_results, aes(x = reorder(toupper(variable), -r2), y = r2, fill = variable)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  scale_fill_manual(values = fill_colors) +
  labs(title = "Regressions on COP", x = "Regressors", y = "R Squared") +
  theme_minimal(base_size = 13)

print(fig1)
save_plot("figure_1.png")

# ==== Figure 2: Normalized Crude Oil Blends with Custom Colors ====

normalize <- function(x) x / x[1]

blend_df <- df %>%
  mutate(across(c(vasconia, brent, wti), normalize)) %>%
  pivot_longer(cols = c(vasconia, brent, wti), names_to = "blend", values_to = "value")

blend_colors <- c(
  "vasconia" = "#6f6ff4",
  "brent"    = "#e264c0",
  "wti"      = "#fb6630"
)

fig2 <- ggplot(blend_df, aes(x = date, y = value, color = blend)) +
  geom_line(alpha = 0.5, size = 0.8) +
  scale_color_manual(values = blend_colors, name = "Blend") +
  labs(
    title = "Crude Oil Blends",
    y = "Normalized Value by 100",
    x = "Date"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    panel.grid.minor = element_blank()
  )

print(fig2)
save_plot("figure_2.png")

# ==== Dual Axis Plot Function (Fixed Scaling) ====
dual_axis_plot <- function(df, y1, y2, label1, label2, title, color1, color2, fname) {
  df <- df %>%
    mutate(y1_scaled = rescale(.data[[y1]], to = c(0, 1)),
           y2_scaled = rescale(.data[[y2]], to = c(0, 1)))
  
  p <- ggplot(df, aes(x = date)) +
    geom_line(aes(y = y1_scaled, color = label1), size = 0.8) +
    geom_line(aes(y = y2_scaled, color = label2), size = 0.8) +
    scale_y_continuous(
      name = paste0(label1, " (rescaled)"),
      sec.axis = sec_axis(~ ., name = paste0(label2, " (rescaled)"))
    ) +
    scale_color_manual(values = setNames(c(color1, color2), c(label1, label2))) +
    labs(title = title, x = "Date", color = NULL) +
    theme_minimal()
  
  print(p)
  ggsave(file.path(out_folder, fname), plot = p, dpi = 300, width = 10, height = 5)
}

# ==== Figures 3–8: Currency Comparisons ====
dual_axis_plot(df, "cop", "gold", "COP", "Gold", "COP vs Gold", "#96CEB4", "#FFA633", "figure_3.png")
dual_axis_plot(df, "cop", "usd", "COP", "USD", "COP vs USD", "#9DE0AD", "#5C4E5F", "figure_4.png")
dual_axis_plot(df, "cop", "brl", "COP", "BRL", "COP vs BRL", "#a4c100", "#f7db4f", "figure_5.png")
dual_axis_plot(df, "usd", "mxn", "USD", "MXN", "USD vs MXN", "#F4A688", "#A2836E", "figure_6.png")
dual_axis_plot(df, "cop", "mxn", "COP", "MXN", "COP vs MXN", "#F26B38", "#B2AD7F", "figure_7.png")
dual_axis_plot(df, "cop", "vasconia", "COP", "Vasconia", "COP vs Vasconia", "#346830", "#BBAB9B", "figure_8.png")

# ==== Figure 9: Before/After Regression Comparison ====
before <- df %>% filter(date <= as.Date("2016-12-31"))
after  <- df %>% filter(date >= as.Date("2017-01-01"))

before_r2 <- summary(lm(cop ~ vasconia, data = before))$r.squared
after_r2  <- summary(lm(cop ~ vasconia, data = after))$r.squared

r2_split_df <- tibble(
  Period = c("Before 2017", "After 2017"),
  R2 = c(before_r2, after_r2)
)

fig9 <- ggplot(r2_split_df, aes(x = Period, y = R2, fill = Period)) +
  geom_col(show.legend = FALSE) +
  scale_fill_manual(values = c("#5DD39E", "#82b74b")) +
  labs(title = "Before/After Regression", y = "R Squared") +
  theme_minimal()
print(fig9); save_plot("figure_9.png")

# ==== Figures 10 & 11: Prediction Bands Before and After 2017 ====
prediction_band_plot <- function(data, period_label, fname) {
  split <- initial_split(data, prop = 0.5)
  train <- training(split)
  test  <- testing(split)
  
  model <- lm(cop ~ vasconia, data = train)
  pred <- predict(model, newdata = test)
  resid_sd <- sd(model$residuals)
  
  test <- test %>% mutate(pred = pred)
  
  p <- ggplot(test, aes(x = date)) +
    geom_line(aes(y = pred), color = "#FEFBD8", size = 1, linetype = "dashed") +
    geom_line(aes(y = cop), color = "#ffd604") +
    geom_ribbon(aes(ymin = pred - resid_sd, ymax = pred + resid_sd), fill = "#F4A688", alpha = 0.6) +
    geom_ribbon(aes(ymin = pred - 2 * resid_sd, ymax = pred + 2 * resid_sd), fill = "#8c7544", alpha = 0.4) +
    labs(title = paste(period_label, "\nR Squared:", round(summary(model)$r.squared * 100, 2), "%"),
         x = "Date", y = "COPAUD") +
    theme_minimal()
  print(p)
  save_plot(fname)
}

prediction_band_plot(before, "Colombian Peso Forecast (Before 2017)", "figure_10.png")
prediction_band_plot(after,  "Colombian Peso Forecast (After 2017)",  "figure_11.png")

# ==== Load our backtest library ====
source("oil_money_trading_backtest.r")

# Prepare the data
portfolio_data <- df %>% filter(date >= as.Date("2016-01-01"))

# ==== Figures 12 & 13: Strategy Simulation & Equity Curve  ====
#  – Generate trade signals on COP vs. Vasconia, run portfolio P&L
signals_bt   <- signal_generation(portfolio_data, "vasconia", "cop", oil_money)
portfolio_bt <- portfolio(signals_bt, "cop")
portfolio_bt$date <- signals_bt$date  # Add date column to portfolio_bt
fig12 <- plot_signals(signals_bt, "cop")   # Figure 12
print(fig12); save_plot("figure_12.png")
fig13 <- graph_profit(portfolio_bt, "cop") # Figure 13
print(fig13); save_plot("figure_13.png")



# === Grid search for parameters ===
grid <- expand.grid(h = 5:19, stop = seq(0.001, 0.005, 0.0005))

results <- grid %>%
  mutate(return = map2_dbl(h, stop, ~{
    sig <- signal_generation(portfolio_data, "vasconia", "cop", oil_money,
                             holding_threshold = .x, stop = .y)
    port <- portfolio(sig, "cop")
    tail(port$asset, 1) / head(port$asset, 1) - 1
  }))

# === Histogram of trading returns ===
# ==== Figure 14 Distribution of Returns ====

fig14 <- ggplot(results, aes(x = return * 100)) +
  geom_histogram(binwidth = 0.50, fill = "#b2660e", color = "white") +
  labs(
    title = "Distribution of Return on COP Trading",
    x = "Return (%)",
    y = "Frequency"
  ) +
  theme_minimal()
print(fig14)
save_plot("figure_14.png")

# === Figure 15: Heatmap of Grid Search Results ===
hm_long <- results %>%
  mutate(stop = as.factor(stop))

fig15 <- ggplot(hm_long, aes(x = stop, y = factor(h), fill = return * 100)) +
  geom_tile(color = "white") +
  scale_fill_viridis_c(name = "Return (%)") +
  scale_y_discrete(limits = rev(levels(factor(hm_long$h)))) +  # Invertir eje Y
  labs(
    title = "Profit Heatmap",
    x = "Stop Profit/Loss",
    y = "Holding Period (days)"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid = element_blank()
  )

print(fig15)
save_plot("figure_15.png")
    