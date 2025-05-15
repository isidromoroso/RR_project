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


#simple regression (r2 vs CAD)

get_r2 <- function(vec) summary(lm(cad ~ vec, data = oil_df))$r.squared

r2_tbl <- tibble(variable = setdiff(cols_order, "cad")) %>%
  mutate(r2 = map_dbl(variable, ~ get_r2(oil_df[[.x]])),
         color = c(rep("#9499a6", 7), "#582a20", "#be7052", "#f2c083",
                   "#9499a6", "#9499a6"))

ggplot(r2_tbl, aes(variable, r2, fill = variable)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  scale_fill_manual(values = r2_tbl$color) +
  labs(title = "Regressions on Loonie", y = "R Squared", x = "Regressors") +
  theme_minimal(base_size = 13) +
  theme(panel.grid.major.x = element_blank())


#normalised currency and crude lines
norm <- function(x) x / x[1]

curr_tbl <- oil_df %>%
  select(date, cad, cny, gbp) %>%
  mutate(across(-date, norm)) %>%
  pivot_longer(-date, names_to = "currency", values_to = "value")

ggplot(curr_tbl, aes(date, value, colour = currency)) +
  geom_line() +
  scale_colour_manual(values = c(cad = "#015249", cny = "#77c9d4", gbp = "#57bc90")) +
  labs(title = "Loonie vs Yuan vs Sterling", y = "Normalised (base 1)", x = NULL) +
  theme_minimal()

crude_tbl <- oil_df %>%
  select(date, wti, wcs, edmonton) %>%
  mutate(across(-date, norm)) %>%
  pivot_longer(-date, names_to = "blend", values_to = "value")

ggplot(crude_tbl, aes(date, value, colour = blend)) +
  geom_line(alpha = 0.6) +
  scale_colour_manual(values = c(wti = "#2a78b2", wcs = "#7b68ee", edmonton = "#110b3c")) +
  labs(title = "Crude Oil Blends", y = "Normalised (base 1)", x = NULL) +
  theme_minimal()

#dual axis example CAD vs WCS
plot_dual <- function(y1, y2, lab1, lab2, ttl) {
  ggplot(oil_df, aes(date)) +
    geom_line(aes(y = y1, colour = lab1)) +
    geom_line(aes(y = y2, colour = lab2)) +
    scale_colour_manual(values = c(lab1 = "#a5a77f", lab2 = "#d8dc2c")) +
    scale_y_continuous(name = lab1, sec.axis = sec_axis(~ ., name = lab2)) +
    labs(title = ttl, x = NULL, colour = NULL) +
    theme_minimal()
}
plot_dual(oil_df$cad, oil_df$wcs, "CAD", "WCS", "Loonie vs WCS")

#K-means clustering CAD,WCS time index
oil_df <- oil_df %>% mutate(idx = row_number())
X <- oil_df %>% select(cad, wcs, idx)

sse <- map_dbl(1:7, ~ kmeans(X, .x, nstart = 20)$tot.withinss / 1e4)
a  <- (sse[1] - last(sse)) / (0 - (length(sse) - 1))
b  <- sse[1] - a * 0
perp_dist <- function(x, y) abs((y - a * x - b) / sqrt(a^2 + 1))
distances <- map_dbl(seq_along(sse) - 1, ~ perp_dist(.x, sse[.x + 1]))

elbow_tbl <- tibble(k = 1:7, SSE = sse, Distance = distances)
ggplot(elbow_tbl, aes(k, SSE)) +
  geom_line(colour = "#116466") +
  geom_line(aes(k, Distance), colour = "#e85a4f") +
  labs(title = "Elbow Method for K-means", x = "Clusters") +
  theme_minimal()

sil_scores <- map_dbl(2:7, ~ mean(silhouette(kmeans(X, .x, nstart = 20)$cluster, dist(X))[, 3]))
best_k <- 2  # matches Python
set.seed(42)
km <- kmeans(X, centers = best_k, nstart = 25)
oil_df$class <- factor(km$cluster)

threshold_idx  <- max(which(oil_df$class == 1))
threshold_date <- oil_df$date[threshold_idx]

plot_ly(oil_df, x = ~wcs, y = ~cad, z = ~idx, color = ~class,
        colors = c("#faed26", "#46344e"), type = "scatter3d", mode = "markers") %>%
  layout(title = "K-means Clusters on Loonie")


#Before / after regression comparison
before_tbl <- filter(oil_df, idx <= threshold_idx)
after_tbl  <- filter(oil_df, idx > threshold_idx)

before_r2 <- summary(lm(cad ~ wcs, data = before_tbl))$r.squared
after_r2  <- summary(lm(cad ~ wcs, data = after_tbl))$r.squared

bar_tbl <- tibble(Period = c(paste0("Before ", threshold_date),
                             paste0("After ", threshold_date)),
                  R2 = c(before_r2, after_r2))

ggplot(bar_tbl, aes(Period, R2, fill = Period)) +
  geom_col(show.legend = FALSE) +
  scale_fill_manual(values = c("Before" = "#f172a1", "After" = "#a1c3d1")) +
  labs(title = "Cluster + Regression", y = "R Squared") +
  theme_minimal()




