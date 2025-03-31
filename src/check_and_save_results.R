pacman::p_load(tidyverse, readxl)

# Try different encodings to see which one works best
cf <- read_csv("output/unique_occupation_matches.csv", locale = locale(encoding = "utf-8"))



glimpse(cf)

set.seed(123)

# Display results to check the merged data
cat("Sample of matched occupations:\n")
cf %>%
    select(
        original_occupation,
        original_matched_kldb_title,
        similarity_score
    ) %>%
    filter(similarity_score < 1) %>%
    filter(similarity_score > 0.99975) %>%
    sample_n(30) %>%
    print(n = 50)

mean(cf$similarity_score > 0.99975)

# Load candidate data set
