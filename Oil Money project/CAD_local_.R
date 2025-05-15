library(readr)        
library(dplyr)        
library(ggplot2)      
library(tidyr)        
library(scales)       
library(cluster)      
library(factoextra) 
library(plotly)       
library(purrr)        
library(rsample)      

DATA_DIR <- "/Users/jackshephard-thorn/Desktop/RR_Project/Repo/RR_project/Oil Money project/data"
CSV_FILE <- "wcs crude cadaud.csv"


#load and tidy data

oil_df <- read_csv(file.path(DATA_DIR, CSV_FILE), show_col_types = FALSE)

cols_order <- c("cny","gbp","usd","eur","krw","mxn","gas",
                "wcs","edmonton","wti","gold","jpy","cad")

oil_df <- oil_df %>%
  mutate(date = as.POSIXct(date, format = "%m/%d/%Y")) %>%
  arrange(date) %>%
  select(date, all_of(cols_order))