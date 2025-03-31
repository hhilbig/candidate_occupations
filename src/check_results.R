pacman::p_load(tidyverse, readxl)

cf <- read_csv("input/matched_data.csv", locale = locale(encoding = "utf-8"))

glimpse(cf)

# Display results to check the merged data
cf %>%
    select(
        occ_1,
        matched_kldb_title
    ) %>%
    head(30) %>%
    print(n = 30)

# Get the preprocessed occupation titles
occ_1_preprocessed <- read_csv("output/preprocessed_occupations_for_embedding.csv")

# Check if occ_1_kldb_title is in the preprocessed data
occ_1_preprocessed %>%
    filter(occupation_clean == occ_1_kldb_title) %>%
    print(n = 30)

# Get the preprocessed KLDB titles
kldb_preprocessed <- read_csv("output/preprocessed_kldb_for_embedding.csv")

kldb_preprocessed %>%
    filter(str_detect(kldb_title, "rechtsanwalt")) %>%
    print(n = 30)
