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
