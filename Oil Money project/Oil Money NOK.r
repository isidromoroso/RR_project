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

