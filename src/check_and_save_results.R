pacman::p_load(tidyverse, readxl)
pacman::p_load_gh("hhilbig/haschaR")

rm(list = ls())

# Read matches
df <- read_csv("output/unique_occupation_matches.csv", locale = locale(encoding = "utf-8")) %>%
    mutate(similarity_score = as.numeric(similarity_score) * 100)
glimpse(df)

# Set threshold
threshold <- 0.9999

set.seed(123)
# Display results to check the merged data
cat("Sample of matched occupations:\n")
df_sample <- df %>%
    select(
        original_occupation,
        original_matched_kldb_title,
        similarity_score
    ) %>%
    filter(!original_occupation == original_matched_kldb_title) %>%
    filter(similarity_score < 100 * 1) %>%
    filter(similarity_score > 100 * threshold) %>%
    sample_n(20) %>%
    print(n = 20)

df_sample

# Save this as a csv
write_csv(df_sample, "output/matches_sample.csv")

mean(df$similarity_score > 100 * threshold)

# Filter matches with similarity score > 99.975%
df_filtered <- df %>%
    filter(similarity_score > 100 * threshold) %>%
    dplyr::select(original_occupation, original_matched_kldb_title, matched_kldb_code)

# Load candidate data set

cf <- read_csv("output/prepped_data.csv",
    locale = locale(encoding = "utf-8")
)

# Create long dataset
# First check if full_name, party, elec_year is a unique identifier
# they are not. we create a new identifier

cf <- cf %>%
    group_by(full_name, party, elec_year) %>%
    mutate(cand_occurence = row_number()) %>%
    ungroup() %>%
    mutate(cand_id = paste0(full_name, "_", party, "_", elec_year, "_", cand_occurence))

# This is an artificial candidate ID to deal w/ the few duplicates in the data

# Create long dataset
cf_long <- cf %>%
    dplyr::select(full_name, party, elec_year, cand_id, occ_1, occ_2, occ_3, occ_4) %>%
    pivot_longer(cols = starts_with("occ_"), names_to = "occupation_number", values_to = "occupation") %>%
    filter(!is.na(occupation))

# Merge with matches
cf_long <- cf_long %>%
    left_join_check_obs(df_filtered, by = c("occupation" = "original_occupation"))

# How many unique candidates have *any* match?
n_cand_with_match <- cf_long %>%
    filter(!is.na(matched_kldb_code)) %>%
    distinct(full_name, party) %>%
    nrow()

# How many unique candidates in total?
n_cand_total <- cf %>%
    distinct(full_name, party) %>%
    nrow()

# Share of candidates with matches
n_cand_with_match / n_cand_total

# Share matched candidates by year
# Calculate share of candidates with matches by election year
cf_long %>%
    group_by(elec_year) %>%
    summarize(
        candidates_with_match = n_distinct(full_name[!is.na(matched_kldb_code)]),
        total_candidates = n_distinct(full_name)
    ) %>%
    mutate(share = candidates_with_match / total_candidates)

# Merge w/ ISCO08 codes

isco08 <- read_excel("input/Umsteigeschluessel-KLDB2020-ISCO08.xlsx", sheet = 2, skip = 5) %>%
    dplyr::select(1, 4) %>%
    dplyr::rename(kldb_code = 1, isco08_code = 2)

# Check for one to many matches

isco08 %>%
    count(kldb_code) %>%
    filter(n > 1)

# Max number of matches
isco08 %>%
    count(kldb_code) %>%
    pull(n) %>%
    max()

# number of unique KLDB codes
isco08 %>%
    pull(kldb_code) %>%
    unique() %>%
    length()

# Create a dataframe that expands the ISCO08 codes into 4 columns
isco08_expanded <- isco08 %>%
    group_by(kldb_code) %>%
    mutate(match_num = row_number()) %>%
    # Create 4 columns for each potential ISCO match
    pivot_wider(
        id_cols = kldb_code,
        names_from = match_num,
        values_from = isco08_code,
        names_prefix = "isco08_code_"
    ) %>%
    # Ensure we have all 4 columns even if some KLDBs have fewer matches
    mutate(
        isco08_code_1 = if_else(is.na(isco08_code_1), NA_character_, isco08_code_1),
        isco08_code_2 = if_else(is.na(isco08_code_2), NA_character_, isco08_code_2),
        isco08_code_3 = if_else(is.na(isco08_code_3), NA_character_, isco08_code_3),
        isco08_code_4 = if_else(is.na(isco08_code_4), NA_character_, isco08_code_4),
        isco08_code_5 = if_else(is.na(isco08_code_5), NA_character_, isco08_code_5)
    )

# Check if all KLDB codes are in isco08_expanded

kldb_in_isco08 <- mean(cf_long$matched_kldb_code %in% isco08_expanded$kldb_code)
cat("Share of KLDB codes that are in isco08_expanded:", kldb_in_isco08, "\n")

# Join the expanded ISCO codes to cf_long
cf_long_with_isco <- cf_long %>%
    left_join_check_obs(isco08_expanded, by = c("matched_kldb_code" = "kldb_code"))

# C

# Add some additional candidate info to this -----------------------------------

glimpse(cf)
glimpse(cf_long_with_isco)

# Merge using cand_id

cf_long_with_isco <- cf_long_with_isco %>%
    left_join_check_obs(cf %>% dplyr::select(list_state, list_rank, elec_district, direct_cand, list_cand, is_legislator, is_only_legislator, cand_id), by = c("cand_id" = "cand_id"))

glimpse(cf_long_with_isco)

# Add flag for duplicated candidate

cf_long_with_isco <- cf_long_with_isco %>%
    group_by(cand_id) %>%
    mutate(is_duplicated_cand = if_else(any(str_detect(cand_id, "_2$")), TRUE, FALSE)) %>%
    ungroup()

sum(cf_long_with_isco$is_duplicated_cand)

# Save ------------------------------------------------------------------------

write_csv(cf_long_with_isco, "output/candidates_with_occupations.csv")

colnames(cf_long_with_isco)
