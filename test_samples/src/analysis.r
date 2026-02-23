# Statistical Analysis Toolkit
library(ggplot2)
library(dplyr)

generate_data <- function(n = 100, seed = 42) {
  set.seed(seed)
  data.frame(
    x = rnorm(n, mean = 50, sd = 10),
    y = rnorm(n, mean = 30, sd = 5),
    group = sample(c("A", "B", "C"), n, replace = TRUE)
  )
}

describe_numeric <- function(x) {
  list(
    n = length(x),
    mean = mean(x, na.rm = TRUE),
    median = median(x, na.rm = TRUE),
    sd = sd(x, na.rm = TRUE),
    min = min(x, na.rm = TRUE),
    max = max(x, na.rm = TRUE),
    q25 = quantile(x, 0.25, na.rm = TRUE),
    q75 = quantile(x, 0.75, na.rm = TRUE)
  )
}

run_ttest <- function(data, col, group_col, g1, g2) {
  v1 <- data[[col]][data[[group_col]] == g1]
  v2 <- data[[col]][data[[group_col]] == g2]
  t.test(v1, v2)
}

# Main analysis
df <- generate_data(200)
cat("Dataset summary:\n")
print(summary(df))

stats_x <- describe_numeric(df$x)
cat(sprintf("\nX stats: mean=%.2f, sd=%.2f, range=[%.2f, %.2f]\n",
    stats_x$mean, stats_x$sd, stats_x$min, stats_x$max))

group_summary <- df %>%
  group_by(group) %>%
  summarise(
    count = n(),
    mean_x = mean(x),
    mean_y = mean(y),
    .groups = "drop"
  )
cat("\nGroup summary:\n")
print(group_summary)

result <- run_ttest(df, "x", "group", "A", "B")
cat(sprintf("\nT-test A vs B: t=%.3f, p=%.4f\n", result$statistic, result$p.value))
