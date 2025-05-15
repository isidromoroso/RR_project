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

