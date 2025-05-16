#load libraries
library(ggplot2)
library(dplyr)
library(readr)
library(lubridate)
library(scales)
library(reshape2)
library(gridExtra)
library(stats)
library(caret)
library(ggpubr)

# Set working directory
setwd("C:\\Users\\Lenovo\\OneDrive\\Pulpit\\RR_project\\repo\\RR_project\\Oil Money project\\data")


# Read data
df <- read_csv("vas crude copaud.csv")
df$date <- ymd(df$date)
df <- df %>% column_to_rownames("date")

# Regressions: R-squared by predictor
regression_results <- sapply(setdiff(colnames(df), "cop"), function(var) {
  model <- lm(cop ~ get(var), data = df)
  summary(model)$r.squared
})

regression_results <- sort(regression_results, decreasing = TRUE)

# Bar plot of R-squared values
colors <- sapply(names(regression_results), function(i) {
  if (i == 'wti') return('#447294')
  else if (i == 'brent') return('#8fbcdb')
  else if (i == 'vasconia') return('#f4d6bc')
  else return('#cdc8c8')
})

barplot(regression_results,
        col = colors,
        main = "Regressions on COP",
        ylab = "R Squared",
        names.arg = toupper(names(regression_results)),
        las = 2)


# Normalize WTI, Brent, Vasconia
df_norm <- df %>%
  mutate(across(c(vasconia, brent, wti), ~ .x / .x[1])) %>%
  select(date = rownames(df), vasconia, brent, wti)

df_long <- melt(df_norm, id.vars = "date")

ggplot(df_long, aes(x = as.Date(date), y = value, color = variable)) +
  geom_line(alpha = 0.6) +
  labs(title = "Crude Oil Blends", x = "Date", y = "Normalized Value by 100")


# Dual axis plot helper
dual_axis_plot <- function(x, y1, y2, y1lab, y2lab, title) {
  df_plot <- data.frame(date = x, y1 = y1, y2 = y2)
  ggplot(df_plot, aes(x = as.Date(date))) +
    geom_line(aes(y = y1, color = y1lab)) +
    geom_line(aes(y = y2, color = y2lab)) +
    scale_color_manual(values = c(y1lab = "#96CEB4", y2lab = "#FFA633")) +
    labs(title = title, x = "Date", y = "") +
    theme_minimal()
}

# Sample dual axis plots (COP vs Gold)
dual_axis_plot(rownames(df), df$cop, df$gold, "COP", "Gold LBMA", "COP VS Gold")

# Before/after regression comparison
before_model <- lm(cop ~ vasconia, data = df[rownames(df) <= "2016", ])
after_model <- lm(cop ~ vasconia, data = df[rownames(df) >= "2017", ])
barplot(c(summary(before_model)$r.squared, summary(after_model)$r.squared),
        names.arg = c("Before 2017", "After 2017"),
        col = c("#82b74b", "#5DD39E"),
        ylab = "R Squared",
        main = "Before/After Regression")

# Train-test split and prediction band
library(rsample)
data_after <- df[rownames(df) >= "2017", ]
split <- initial_split(data_after, prop = 0.5)
train <- training(split)
test <- testing(split)

model <- lm(cop ~ vasconia, data = test)
pred <- predict(model, newdata = test)
resid_sd <- sd(model$residuals)

test$date <- as.Date(rownames(test))

ggplot(test, aes(x = date)) +
  geom_line(aes(y = cop), color = "#ffd604", label = "Actual") +
  geom_line(aes(y = pred), color = "#FEFBD8", label = "Fitted") +
  geom_ribbon(aes(ymin = pred - resid_sd, ymax = pred + resid_sd), fill = "#F4A688", alpha = 0.6) +
  geom_ribbon(aes(ymin = pred - 2 * resid_sd, ymax = pred + 2 * resid_sd), fill = "#8c7544", alpha = 0.4) +
  labs(title = paste("Colombian Peso Positions\nR Squared:", round(summary(model)$r.squared * 100, 2), "%"),
       x = "Date", y = "COPAUD")

# Optimization over parameters
results <- expand.grid(holding = 5:19, stop = seq(0.001, 0.0045, 0.0005))
results$return <- runif(nrow(results), min = -0.05, max = 0.15)  # demo values

# Distribution of return
ggplot(results, aes(x = return * 100)) +
  geom_histogram(fill = "#b2660e", bins = 20, width = 2) +
  labs(title = "Distribution of Return on COP Trading", x = "Return (%)", y = "Frequency")


