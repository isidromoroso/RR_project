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

