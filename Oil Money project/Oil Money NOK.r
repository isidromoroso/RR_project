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

