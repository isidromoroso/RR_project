# Required Libraries
library(TTR)
library(quantmod)
library(dplyr)
library(ggplot2)
library(zoo)
library(xts)
library(PerformanceAnalytics)

# Oil money function
oil_money <- function(dataset) {
  df <- dataset
  df$signals <- 0
  df$`pos2 sigma` <- 0.0
  df$`neg2 sigma` <- 0.0
  df$`pos1 sigma` <- 0.0
  df$`neg1 sigma` <- 0.0
  df$forecast <- 0.0
  return(df)
}
