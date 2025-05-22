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

graphics.off()

# ==== Load and Clean Data ====
data_path <- "C:/Users/Lenovo/OneDrive/Pulpit/RR_project/repo/RR_project/Oil Money project/data/vas crude copaud.csv"
df <- read_csv(data_path, show_col_types = FALSE)
df$date <- parse_date_time(df$date, orders = c("ymd", "mdy", "dmy"))
df <- df %>% filter(!is.na(date)) %>% arrange(date)

# ==== Output Folder ====
out_folder <- "COP Data/r_graphs_original"
dir.create(out_folder, recursive = TRUE, showWarnings = FALSE)

save_plot <- function(filename) {
  ggsave(file.path(out_folder, filename), dpi = 300, width = 10, height = 5)
}

# ==== Figure 1: R-squared Bar Chart ====
r2_results <- df %>%
  select(-date, -cop) %>%
  summarise(across(everything(), ~ summary(lm(df$cop ~ .x))$r.squared)) %>%
  pivot_longer(cols = everything(), names_to = "variable", values_to = "r2") %>%
  arrange(desc(r2))

r2_results$color <- case_when(
  r2_results$variable == "wti" ~ "#447294",
  r2_results$variable == "brent" ~ "#8fbcdb",
  r2_results$variable == "vasconia" ~ "#f4d6bc",
  TRUE ~ "#cdc8c8"
)

fig1 <- ggplot(r2_results, aes(x = reorder(toupper(variable), -r2), y = r2, fill = variable)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  scale_fill_manual(values = r2_results$color) +
  labs(title = "Regressions on COP", x = "Regressors", y = "R Squared") +
  theme_minimal(base_size = 13)
print(fig1); save_plot("figure_1.png")

# ==== Figure 2: Normalized Crude Oil Blends ====
normalize <- function(x) x / x[1]

blend_df <- df %>%
  mutate(across(c(vasconia, brent, wti), normalize)) %>%
  pivot_longer(cols = c(vasconia, brent, wti), names_to = "blend", values_to = "value")

fig2 <- ggplot(blend_df, aes(x = date, y = value, color = blend)) +
  geom_line(alpha = 0.6) +
  labs(title = "Crude Oil Blends", y = "Normalized Value by 100", x = "Date") +
  theme_minimal()
print(fig2); save_plot("figure_2.png")

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
dual_axis_plot(df, "cop", "usd", "COP", "USD", "COP vs USD", "#9DE0AD", "#5C4E5F", "figure_3.png")
dual_axis_plot(df, "cop", "brl", "COP", "BRL", "COP vs BRL", "#a4c100", "#f7db4f", "figure_4.png")
dual_axis_plot(df, "usd", "mxn", "USD", "MXN", "USD vs MXN", "#F4A688", "#A2836E", "figure_5.png")
dual_axis_plot(df, "cop", "mxn", "COP", "MXN", "COP vs MXN", "#F26B38", "#B2AD7F", "figure_6.png")
dual_axis_plot(df, "cop", "vasconia", "COP", "Vasconia", "COP vs Vasconia", "#346830", "#BBAB9B", "figure_7.png")
dual_axis_plot(df, "cop", "gold", "COP", "Gold", "COP vs Gold", "#96CEB4", "#FFA633", "figure_8.png")

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
  scale_fill_manual(values = c("#82b74b", "#5DD39E")) +
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

# ==== Figure 12: Strategy Simulation Equity Curve ====
strategy_data <- df %>% filter(date >= as.Date("2016-01-01")) %>% mutate(spread = scale(cop - vasconia))
threshold <- 1

signals <- strategy_data %>%
  mutate(position = case_when(
    spread > threshold  ~ -1,
    spread < -threshold ~ 1,
    TRUE ~ 0
  )) %>%
  mutate(return = lag(position) * (cop - lag(cop))) %>%
  mutate(asset = 100 + cumsum(replace_na(return, 0)))

fig12 <- ggplot(signals, aes(x = date, y = asset)) +
  geom_line(color = "#01BAEF") +
  labs(title = "Performance", x = "Date", y = "Total Asset Value") +
  theme_minimal()
print(fig12); save_plot("figure_12.png")

# ==== Figure 13: Trade Signal Timing ====
fig13 <- ggplot(signals, aes(x = date)) +
  geom_line(aes(y = cop, color = "COP")) +
  geom_point(data = filter(signals, position != 0), aes(y = cop, color = as.factor(position)), shape = 17, size = 2) +
  scale_color_manual(values = c("COP" = "black", "-1" = "red", "1" = "green")) +
  labs(title = "Entry/Exit Signal Plot", y = "COP", color = NULL) +
  theme_minimal()
print(fig13); save_plot("figure_13.png")

# ==== Figure 14: Return Distribution ====
final_returns <- signals %>% filter(!is.na(return))
fig14 <- ggplot(final_returns, aes(x = return * 100)) +
  geom_histogram(
    fill = "#b2660e",
    color = "white",
    binwidth = 1,   # matches Python's width=0.45, bins=20 over ~9% range
    boundary = 0
  ) +
  theme_minimal(base_size = 14) +
  theme(panel.grid = element_blank()) +
  labs(
    title = "Distribution of Return on COP Trading",
    x = "Return (%)",
    y = "Frequency"
  )
print(fig14)
save_plot("figure_14.png")


library(ggplot2)

# Reshape heatmap data for ggplot
hm_long <- test_results %>%
  mutate(stop = as.factor(stop))  # keep stop numeric-looking on x-axis

fig15 <- ggplot(hm_long, aes(x = stop, y = factor(holding), fill = return * 100)) +
  geom_tile(color = "white") +
  scale_fill_viridis_c(name = "Return(%)", option = "viridis") +
  theme_minimal(base_size = 13) +
  labs(
    title = "Profit Heatmap",
    x = "Stop Loss/Profit (points)",
    y = "Position Holding Period (days)"
  ) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid = element_blank()
  )

print(fig15)
save_plot("figure_15.png")


