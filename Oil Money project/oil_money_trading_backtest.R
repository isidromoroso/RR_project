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

# Signal generation function
signal_generation <- function(dataset, x, y, method,
                              holding_threshold = 10,
                              stop = 0.5,
                              rsquared_threshold = 0.7,
                              train_len = 50) {
  df <- method(dataset)
  holding <- 0
  trained <- FALSE
  counter <- 0
  
  for (i in (train_len + 1):nrow(df)) {
    if (holding != 0) {
      if (counter > holding_threshold) {
        df$signals[i] <- -holding
        holding <- 0
        trained <- FALSE
        counter <- 0
        next
      }
      entry_price <- tail(df[[y]][which(df$signals != 0)], 1)
      if (length(entry_price) > 0 && abs(df[[y]][i] - entry_price) >= stop) {
        df$signals[i] <- -holding
        holding <- 0
        trained <- FALSE
        counter <- 0
        next
      }
      counter <- counter + 1
    } else {
      if (!trained) {
        X <- df[[x]][(i - train_len):(i - 1)]
        Y <- df[[y]][(i - train_len):(i - 1)]
        model <- lm(Y ~ X)
        rsq <- summary(model)$r.squared
        
        if (rsq > rsquared_threshold) {
          trained <- TRUE
          sigma <- sd(Y - predict(model))
          
          future_X <- df[[x]][i:nrow(df)]
          new_data <- data.frame(X = future_X)
          
          if (nrow(new_data) == length(future_X)) {
            preds <- predict(model, newdata = new_data)
            df$forecast[i:nrow(df)] <- preds
            df$`pos2 sigma`[i:nrow(df)] <- preds + 2 * sigma
            df$`neg2 sigma`[i:nrow(df)] <- preds - 2 * sigma
            df$`pos1 sigma`[i:nrow(df)] <- preds + sigma
            df$`neg1 sigma`[i:nrow(df)] <- preds - sigma
          }
        }
      }
      
      if (trained && !is.na(df[[y]][i]) && !is.na(df$`pos2 sigma`[i])) {
        if (df[[y]][i] > df$`pos2 sigma`[i]) {
          df$signals[i] <- 1
          holding <- 1
          df[i:nrow(df), c("pos2 sigma", "neg2 sigma", "pos1 sigma", "neg1 sigma")] <- df$forecast[i:nrow(df)]
        } else if (df[[y]][i] < df$`neg2 sigma`[i]) {
          df$signals[i] <- -1
          holding <- -1
          df[i:nrow(df), c("pos2 sigma", "neg2 sigma", "pos1 sigma", "neg1 sigma")] <- df$forecast[i:nrow(df)]
        }
      }
    }
  }
  return(df)
}

# Portfolio function
portfolio <- function(signals, close_price, capital0 = 5000) {
  positions <- floor(capital0 / max(signals[[close_price]], na.rm = TRUE))
  portfolio <- data.frame(
    close = signals[[close_price]],
    signals = signals$signals
  )
  portfolio$holding <- cumsum(portfolio$signals) * portfolio$close * positions
  portfolio$cash <- capital0 - cumsum(portfolio$signals * portfolio$close * positions)
  portfolio$asset <- portfolio$holding + portfolio$cash
  return(portfolio)
}

# Plotting fitted vs actual price
plot_signals <- function(signals, close_price) {
  data <- subset(signals, forecast != 0)
  data$date <- as.Date(data$date)
  p <- ggplot(data, aes(x = date)) +
    geom_line(aes(y = forecast, color = "Fitted"), alpha = 0.7) +
    geom_line(aes_string(y = close_price, color = shQuote("Actual")), alpha = 0.7) +
    geom_ribbon(aes(ymin = `neg1 sigma`, ymax = `pos1 sigma`), fill = "#011f4b", alpha = 0.3) +
    geom_ribbon(aes(ymin = `neg2 sigma`, ymax = `pos2 sigma`), fill = "#ffc425", alpha = 0.3) +
    geom_point(data = subset(data, signals == 1), aes_string(y = close_price), color = "#00b159", shape = 24, size = 3) +
    geom_point(data = subset(data, signals == -1), aes_string(y = close_price), color = "#ff6f69", shape = 25, size = 3) +
    labs(title = paste("Oil Money Project\n", toupper(close_price), "Positions"),
         x = "Date", y = "Price") +
    scale_color_manual(values = c("Fitted" = "#f4f4f8", "Actual" = "#3c2f2f")) +
    theme_minimal()
  print(p)
}

# Plotting portfolio performance
graph_profit <- function(portfolio, close_price) {
  portfolio$date <- as.Date(portfolio$date)
  p <- ggplot(portfolio, aes(x = date, y = asset)) +
    geom_line(color = "#58668b") +
    geom_point(data = subset(portfolio, signals == 1), aes(y = asset), color = "#00b159", shape = 24, size = 3) +
    geom_point(data = subset(portfolio, signals == -1), aes(y = asset), color = "#ff6f69", shape = 25, size = 3) +
    labs(title = paste("Oil Money Project\n", toupper(close_price), "Total Asset"),
         x = "Date", y = "Asset Value") +
    theme_minimal()
  print(p)
}

# Main function
main <- function() {
  df <- read.csv("data/brent crude nokjpy.csv", check.names = FALSE)
  colnames(df) <- gsub("﻿", "", colnames(df))
  colnames(df)[1] <- "date"
  
  df$date <- as.Date(df$date, format = "%m/%d/%Y")
  
  signals <- signal_generation(df, "brent", "nok", oil_money)
  signals$date <- df$date
  
  p <- portfolio(signals, "nok")
  p$date <- df$date

  plot_signals(signals[387:600, ], "nok")
  graph_profit(p[387:600, ], "nok")
  
}

# Run main
main()