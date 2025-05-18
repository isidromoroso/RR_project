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

