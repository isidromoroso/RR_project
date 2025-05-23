# 0) Ensure webshot is installed for 3D PNG export ------------------------
if (!requireNamespace("webshot", quietly = TRUE)) {
  install.packages("webshot")
  webshot::install_phantomjs()
}
library(webshot)

# 1) Load libraries --------------------------------------------------------
library(rsample)
library(readr)
library(dplyr)
library(ggplot2)
library(tidyr)
library(scales)
library(cluster)
library(factoextra)
library(plotly)
library(purrr)
library(htmlwidgets)

# 2) Prepare output folder ------------------------------------------------
base_dir   <- "/Users/jackshephard-thorn/Desktop/RR_Project/Repo/RR_project/Oil Money project/CAD data"
out_folder <- file.path(base_dir, "original_graphs_r")
if (!dir.exists(out_folder)) dir.create(out_folder, recursive = TRUE)

# 3) Load & tidy data -----------------------------------------------------
data_dir <- "/Users/jackshephard-thorn/Desktop/RR_Project/Repo/RR_project/Oil Money project/data"
csv_file <- "wcs crude cadaud.csv"

oil_df <- read_csv(file.path(data_dir, csv_file), show_col_types = FALSE) %>%
  mutate(date = as.POSIXct(date, format = "%m/%d/%Y")) %>%
  arrange(date) %>%
  select(date,
         cny, gbp, usd, eur, krw, mxn, gas,
         wcs, edmonton, wti, gold, jpy, cad)

# 4) Compute R² for each regressor ----------------------------------------
library(tidyverse)

# Variables to exclude (in addition to "cad" and "date")
exclude_vars <- c("cad", "date")

# Calculate R² for all variables except the excluded ones
r2_tbl <- oil_df %>%
  select(-all_of(exclude_vars)) %>%
  summarise(across(everything(), ~ summary(lm(oil_df$cad ~ .x))$r.squared)) %>%
  pivot_longer(cols = everything(), names_to = "variable", values_to = "r2") %>%
  arrange(desc(r2))

# Define colors for some specific variables
fill_colors <- c(
  "wcs" = "#582a20",  
  "edmonton" = "#be7052",
  "wti" = "#f2c083"
)

# Variables without assigned color
other_vars <- setdiff(r2_tbl$variable, names(fill_colors))
fill_colors <- c(fill_colors, setNames(rep("#9499a6", length(other_vars)), other_vars))

# Plot
ggplot(r2_tbl, aes(x = reorder(variable, -r2), y = r2, fill = variable)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  scale_fill_manual(values = fill_colors) +
  labs(title = "Regressions on Loonie", y = "R Squared", x = "Regressors") +
  theme_minimal(base_size = 13) +
  theme(panel.grid.major.x = element_blank())

# 5) Normalize series ------------------------------------------------------
norm     <- function(x) x / x[1]
curr_tbl <- oil_df %>%
  select(date, cad, cny, gbp) %>%
  mutate(across(-date, norm)) %>%
  pivot_longer(-date, names_to = "currency", values_to = "value")

crude_tbl <- oil_df %>%
  select(date, wti, wcs, edmonton) %>%
  mutate(across(-date, norm)) %>%
  pivot_longer(-date, names_to = "blend", values_to = "value")

# 6) Prepare k-means diagnostics ------------------------------------------
oil_df <- oil_df %>% mutate(idx = row_number())
X      <- oil_df %>% select(cad, wcs, idx)

# Elbow
sse       <- map_dbl(1:7, ~ kmeans(X, .x, nstart = 20)$tot.withinss / 1e4)
a         <- (sse[1] - last(sse)) / (0 - (length(sse) - 1))
b         <- sse[1] - a * 0
perp_dist <- function(x, y) abs((y - a * x - b) / sqrt(a^2 + 1))
distances <- map_dbl(seq_along(sse) - 1, ~ perp_dist(.x, sse[.x + 1]))
elbow_tbl <- tibble(k = 1:7, SSE = sse, Distance = distances)

# Silhouette scores
sil_scores <- map_dbl(2:7,
                      ~ mean(silhouette(kmeans(X, .x, nstart = 20)$cluster,
                                        dist(X))[, 3]))
sil_tbl <- tibble(k = 2:7, Silhouette = sil_scores)

# Final clustering & before/after split
best_k        <- which.max(sil_scores) + 1
set.seed(42)
km            <- kmeans(X, centers = best_k, nstart = 25)
oil_df$class  <- factor(km$cluster)
threshold_idx <- min(which(oil_df$class == as.character(best_k)))
threshold_date<- oil_df$date[threshold_idx]
before_tbl    <- filter(oil_df, idx <= threshold_idx)
after_tbl     <- filter(oil_df, idx >  threshold_idx)
before_r2     <- summary(lm(cad ~ wcs, data = before_tbl))$r.squared
after_r2      <- summary(lm(cad ~ wcs, data = after_tbl))$r.squared
bar_tbl       <- tibble(
  Period = c(paste0("Before ", threshold_date),
             paste0("After  ",  threshold_date)),
  R2     = c(before_r2, after_r2)
)

# 7) Dual‐axis helper ------------------------------------------------------
plot_dual <- function(y1, y2, lab1, lab2, ttl) {
  ggplot(oil_df, aes(date)) +
    geom_line(aes(y = y1, colour = lab1)) +
    geom_line(aes(y = y2, colour = lab2)) +
    scale_colour_manual(values = setNames(c("#a5a77f", "#d8dc2c"),
                                          c(lab1, lab2))) +
    scale_y_continuous(name = lab1,
                       sec.axis = sec_axis(~ ., name = lab2)) +
    labs(title = ttl, x = NULL, colour = NULL) +
    theme_minimal()
}

# 8) Collect all ggplots ---------------------------------------------------
plots <- list()

# (1) R² bar chart
p1 <- ggplot(r2_tbl, aes(x = reorder(variable, -r2), y = r2, fill = variable)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  scale_fill_manual(values = fill_colors) +
  scale_x_discrete(labels = c("Yuan","Sterling","Dollar","Euro","KRW",
                              "MXN","Gas","WCS","Edmonton","WTI","Gold","Yen")) +
  labs(title="Regressions on Loonie", y="R Squared", x="\nRegressors") +
  theme_minimal(base_size=13) +
  theme(panel.grid=element_blank())

print(p1)
plots[[length(plots)+1]] <- recordPlot()

# (2) Normalised currencies
p2 <- curr_tbl %>%
  mutate(currency=factor(currency, levels=c("cny","gbp","cad"))) %>%
  ggplot(aes(date, value, colour=currency)) +
  geom_line() +
  scale_colour_manual(
    values = c(cny="#77c9d4", gbp="#57bc90", cad="#015249"),
    labels = c("Yuan","Sterling","Loonie")
  ) +
  labs(title="Loonie vs Yuan vs Sterling",
       x="Date", y="Normalized Value by 100", colour=NULL) +
  theme_minimal()
print(p2); plots[[length(plots)+1]] <- recordPlot()

# (3) Crude-blends line
p3 <- ggplot(crude_tbl, aes(date, value, colour=blend)) +
  geom_line(alpha=0.5) +
  scale_colour_manual(
    values = c(wti="#2a78b2", wcs="#7b68ee", edmonton="#110b3c"),
    labels = c("WTI","WCS","Edmonton")
  ) +
  labs(title="Crude Oil Blends",
       x="Date", y="Normalized Value by 100", colour=NULL) +
  theme_minimal()
print(p3); plots[[length(plots)+1]] <- recordPlot()

# (4) Dual‐axis CAD vs WCS (AUD) with aligned scales -----------------------

# precompute scaling factor
ratio_aud <- max(oil_df$wcs, na.rm = TRUE) /
  max(oil_df$cad, na.rm = TRUE)

p4 <- ggplot(oil_df, aes(x = date)) +
  # Loonie on the primary axis
  geom_line(aes(y = cad,   colour = "Canadian Dollar"), size = 1) +
  # WCS down-scaled to sit on same axis
  geom_line(aes(y = wcs/ratio_aud, colour = "Western Canadian Select"),
            size = 1) +
  scale_colour_manual(
    values = c(
      "Canadian Dollar"            = "#a5a77f",
      "Western Canadian Select"    = "#d8dc2c"
    )
  ) +
  scale_y_continuous(
    name     = "Canadian Dollar",
    sec.axis = sec_axis(~ . * ratio_aud,
                        name = "Western Canadian Select")
  ) +
  labs(
    title  = "Loonie VS WCS in AUD",
    x      = "Date",
    colour = NULL
  ) +
  theme_minimal()

print(p4)
plots[[length(plots) + 1]] <- recordPlot()

# (5) Dual‐axis “Loonie vs WCS in USD” 
library(scales)

# recompute your ratio as before
ratio <- max(oil_df$wcs  / oil_df$usd, na.rm = TRUE) /
  max(oil_df$cad  / oil_df$usd, na.rm = TRUE)

p5 <- ggplot(oil_df, aes(date)) +
  # primary CAD(USD)
  geom_line(aes(y = cad / usd, colour = "Loonie"), size = 1) +
  # secondary WCS(USD) scaled into the same panel
  geom_line(aes(y = (wcs / usd) / ratio, colour = "WCS"), size = 1) +
  scale_colour_manual(
    values = c(Loonie = "#F58220", WCS = "#7B3F00")
  ) +
  scale_y_continuous(
    name     = "Canadian Dollar (USD)",
    limits   = c(0, 1.0),            # only show CAD between –1
    oob      = squish,                # “squish” any out‐of‐bounds points to the nearest limit
    sec.axis = sec_axis(
      ~ . * ratio,
      name = "Western Canadian Select (USD)"
    )
  ) +
  labs(
    title  = "Loonie VS WCS in USD",
    x      = "Date",
    colour = NULL
  ) +
  theme_minimal()

print(p5)
plots[[length(plots) + 1]] <- recordPlot()

# (6) Elbow method with proper dual‐axis scaling --------------------------
# compute factor to map Distance → SSE
scale_factor <- max(elbow_tbl$SSE,      na.rm = TRUE) /
  max(elbow_tbl$Distance, na.rm = TRUE)

p6 <- ggplot(elbow_tbl, aes(x = k)) +
  # SSE on primary axis
  geom_line(aes(y = SSE, colour = "SSE"), size = 1) +
  # Distance scaled up to SSE range
  geom_line(aes(y = Distance * scale_factor, colour = "Distance"), size = 1) +
  scale_colour_manual(values = c(SSE = "#116466", Distance = "#e85a4f")) +
  scale_y_continuous(
    name     = "Sum of Squared Error",
    # secondary axis undoes the scaling
    sec.axis = sec_axis(~ . / scale_factor,
                        name = "Perpendicular Distance")
  ) +
  labs(
    title  = "Elbow Method for K Means",
    x      = "Numbers of Cluster",
    colour = NULL
  ) +
  theme_minimal(base_size = 13)

print(p6)
plots[[length(plots) + 1]] <- recordPlot()

# (7) Silhouette Analysis
peak <- sil_tbl %>% filter(Silhouette == max(Silhouette))
p7 <- ggplot(sil_tbl, aes(k, Silhouette)) +
  geom_step(direction="mid") +
  geom_point(data=peak, aes(k, Silhouette), shape="*", size=6) +
  labs(title="Silhouette Analysis for K Means",
       x="Numbers of Cluster", y="Silhouette Score") +
  theme_minimal()
print(p7); plots[[length(plots)+1]] <- recordPlot()

# (8) 3D cluster scatter static  **NEW**
threshold <- max(which(oil_df$class=="1"))
library(scatterplot3d)
s3d <- scatterplot3d(
  x     = oil_df$wcs,
  y     = oil_df$cad,
  z     = as.numeric(oil_df$date),
  color = ifelse(oil_df$class=="1", "#faed26", "#46344e"),
  pch   = 19, cex.symbols=0.5,
  main  = "K Means on Loonie", xlab="WCS", ylab="Loonie", zlab="Date"
)
legend("topright",
       legend = c(paste("Before", threshold),
                  paste("After",  threshold)),
       col    = c("#faed26","#46344e"),
       pch    = 19, bty="n")
plots[[length(plots)+1]] <- recordPlot()

# (9) Cluster + Regression R² bar chart
before_r2 <- summary(lm(cad ~ wcs, data=oil_df, subset=(class=="1")))$r.squared
after_r2  <- summary(lm(cad ~ wcs, data=oil_df, subset=(class=="2")))$r.squared
bar_df <- tibble(
  Stage = c(paste("Before", threshold), paste("After", threshold)),
  R2    = c(before_r2, after_r2)
)
p9 <- ggplot(bar_df, aes(Stage, R2, fill=Stage)) +
  geom_col(width=0.7, show.legend=FALSE) +
  scale_fill_manual(values=c("#f172a1","#a1c3d1")) +
  labs(title="Cluster + Regression", y="R Squared") +
  theme_minimal() +
  theme(panel.grid=element_blank())
print(p9); plots[[length(plots)+1]] <- recordPlot()

# (10)&(11) Prediction-bands by cluster
for(cl in levels(oil_df$class)) {
  sub   <- filter(oil_df, class==cl)
  split <- initial_split(sub, prop=0.5)
  train <- training(split); test <- testing(split)
  fit   <- lm(cad ~ wcs, data=train)
  fc    <- predict(fit, newdata=test)
  sde   <- sd(residuals(fit))
  dfp   <- test %>% mutate(Fitted=fc,
                           U1=fc+sde, L1=fc-sde,
                           U2=fc+2*sde, L2=fc-2*sde)
  p <- ggplot(dfp, aes(date)) +
    geom_line(aes(y=Fitted)) +
    geom_line(aes(y=cad)) +
    geom_ribbon(aes(ymin=L1, ymax=U1), alpha=0.3) +
    geom_ribbon(aes(ymin=L2, ymax=U2), alpha=0.2) +
    labs(
      title=paste(if(cl=="1") "Before" else "After", threshold,
                  "\nR Squared", sprintf("%.2f%%", summary(fit)$r.squared*100)),
      x="Date", y="CADAUD"
    ) +
    theme_minimal()
  print(p); plots[[length(plots)+1]] <- recordPlot()
}

# 9) Write out all static ggplots to PNG ----------------------------------
for(i in seq_along(plots)) {
  png(file.path(out_folder, sprintf("figure_%02d.png", i)),
      width=8, height=6, units="in", res=300)
  replayPlot(plots[[i]]); dev.off()
}

# 10) Export the interactive 3D as PNG via webshot ------------------------
html <- file.path(out_folder, "scatter3d.html")
saveWidget(widget = p3d, file = html, selfcontained=TRUE)
webshot(html,
        file   = file.path(out_folder, "figure_11_3d_scatter.png"),
        vwidth = 800, vheight = 600)

