pacman::p_load(tidyverse, haschaR, readxl, stringi)

# Get the data and assign an ID immediately
cf <- read_rds("input/candidates_all_80_21.rds") %>%
    dplyr::select(1:15) %>%
    mutate(id = row_number()) %>%
    mutate(occupation = str_squish(occupation)) %>%
    mutate(occupation = stringi::stri_trans_tolower(occupation))

# Replace ae with ä, oe with ö, and ue with ü only if a/o/u are not preceded by another vowel.
cf <- cf %>%
    mutate(occupation = str_replace_all(occupation, "(?<![aeiou])ae", "ä")) %>%
    mutate(occupation = str_replace_all(occupation, "(?<![aeiou])oe", "ö")) %>%
    mutate(occupation = str_replace_all(occupation, "(?<![aeiou])ue", "ü"))

glimpse(cf)

# Steps:
# 1. Separate multiple occupations (divided e.g., by commas or "und").
#    Create new columns for each separated occupation (occ_1, occ_2, etc.). They can be NA for people with only one occupation.
# 2. Mark all occupations that *only* refer to the fact that they are MPs or another type of legislator.

# Step 1: Separate multiple occupations
# Replace "und" with a comma to standardize separators
cf <- cf %>%
    mutate(occupation = str_replace_all(occupation, " und ", ", "))

# Split occupations by comma and convert to long format.
# Note: We delay the removal of punctuation until after splitting so that commas remain intact for splitting.
occupations_split <- cf %>%
    filter(!is.na(occupation)) %>%
    # Remove "a.d." (ausser dienst) from occupation titles
    mutate(occupation = str_replace_all(occupation, " a\\.d\\.", "")) %>%
    mutate(occupation = str_replace_all(occupation, "a\\.d\\. ", "")) %>%
    mutate(occupation = str_replace_all(occupation, "a\\.d\\.,", ",")) %>%
    mutate(occupation = str_replace_all(occupation, "\\(a\\.d\\.\\)", "")) %>%
    # Remove "i.r." (in ruhestand) similar to a.d.
    mutate(occupation = str_replace_all(occupation, " i\\.r\\.", "")) %>%
    mutate(occupation = str_replace_all(occupation, "i\\.r\\. ", "")) %>%
    mutate(occupation = str_replace_all(occupation, "i\\.r\\.,", ",")) %>%
    mutate(occupation = str_replace_all(occupation, "\\(i\\.r\\.\\)", "")) %>%
    # Expand common abbreviations
    mutate(occupation = str_replace_all(occupation, "\\bmdb\\b", "mitglied des bundestages")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bmdl\\b", "mitglied des landtages")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bmdab\\b", "mitglied des abgeordnetenhauses")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bmdep\\b", "mitglied des europäischen parlaments")) %>%
    mutate(occupation = str_replace_all(occupation, "dipl\\.-", "diplom-")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bdipl\\.", "diplom")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bdr\\.", "doktor")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bprof\\.", "professor")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bm\\. ?a\\.", "master of arts")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bb\\. ?a\\.", "bachelor of arts")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bm\\. ?sc\\.", "master of science")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bb\\. ?sc\\.", "bachelor of science")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bkfm\\.", "kaufmännisch")) %>%
    mutate(occupation = str_replace_all(occupation, "\\btechn\\.", "technisch")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bwiss\\.", "wissenschaftlich")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bparl\\.", "parlamentarisch")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bmba\\b", "master of business administration")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bfh\\b", "fachhochschule")) %>%
    mutate(occupation = str_replace_all(occupation, "\\buniv\\.", "universität")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bö\\. d\\.", "öffentlicher dienst")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bselbst\\.", "selbständig")) %>%
    # Clean up some common occupation patterns
    mutate(occupation = str_replace_all(occupation, "\\bstrin\\b", "studienrätin")) %>%
    mutate(occupation = str_replace_all(occupation, "\\bstr\\b", "studienrat")) %>%
    # Fix umlauts in common words
    mutate(occupation = str_replace_all(occupation, "buergermeister", "bürgermeister")) %>%
    mutate(occupation = str_replace_all(occupation, "praesident", "präsident")) %>%
    # Remove parenthetical qualifications that don't add occupation information
    mutate(occupation = str_replace_all(occupation, "\\([^)]*\\)", "")) %>%
    # Standardize inconsistent occupational titles
    mutate(occupation = str_replace_all(occupation, "\\bargbeordnete[r]?\\b", "abgeordnete")) %>%
    # Consistent formatting for "selbständig" variations
    mutate(occupation = str_replace_all(occupation, "selbständige[r]? ", "selbständig ")) %>%
    # Additional text cleaning and normalization (do NOT remove commas here)
    mutate(
        occupation = str_replace_all(occupation, "[0-9]", " "), # Remove numbers
        occupation = str_squish(occupation)
    ) %>%
    # Remove stopwords (German stopwords list)
    mutate(
        occupation = map_chr(occupation, function(text) {
            german_stopwords <- c("und", "der", "die", "das", "in", "für", "von", "mit", "bei", "im", "an", "zu", "auf")
            words <- unlist(str_split(text, "\\s+"))
            words <- words[!words %in% german_stopwords]
            paste(words, collapse = " ")
        })
    ) %>%
    # Additional abbreviation handling
    mutate(
        occupation = str_replace_all(occupation, "u\\.", "und"),
        occupation = str_replace_all(occupation, "d\\. h\\.", "das heißt"),
        occupation = str_replace_all(occupation, "z\\. b\\.", "zum beispiel"),
        occupation = str_replace_all(occupation, "v\\. a\\.", "vor allem"),
        occupation = str_replace_all(occupation, "o\\. ä\\.", "oder ähnlich")
    ) %>%
    mutate(occupation = str_squish(occupation)) %>%
    # Split occupations based on commas (with optional whitespace)
    separate_rows(occupation, sep = ",\\s*") %>%
    filter(occupation != "") %>%
    # Now remove unwanted punctuation from each individual occupation
    mutate(occupation = str_replace_all(occupation, "[[:punct:]]", " ")) %>%
    mutate(occupation = str_squish(occupation))

# Determine maximum number of occupations per person
max_occupations <- occupations_split %>%
    group_by(id) %>%
    summarise(n_occupations = n()) %>%
    pull(n_occupations) %>%
    max(na.rm = TRUE)

# Create the occupation columns (occ_1, occ_2, etc.)
cf_wide <- occupations_split %>%
    group_by(id) %>%
    mutate(occ_num = row_number()) %>%
    pivot_wider(
        id_cols = id,
        names_from = occ_num,
        values_from = occupation,
        names_prefix = "occ_"
    )

# Join back to the original data using the pre-assigned id
cf <- cf %>%
    left_join(cf_wide, by = "id") %>%
    select(-id)

glimpse(cf_wide)

# Step 2: Mark legislators
# Define patterns for legislators - expanded list based on data exploration
legislator_patterns <- c(
    # Original patterns
    "mitglied des deutschen bundestages",
    "mitglied des bundestages",
    "mitglied des landtages",
    "abgeordneter",
    "abgeordnete",
    "bundestagsabgeordneter",
    "bundestagsabgeordnete",
    "mdb",

    # Additional patterns found in the data
    "parlamentarisch staatssekretaer",
    "parlamentarisch staatssekretär",
    "mitglied des abgeordnetenhauses",
    "bundesminister",
    "bundesministerin",
    "staatsminister",
    "staatsministerin",
    "bürgermeister",
    "bürgermeisterin",
    "erster bürgermeister",
    "erste bürgermeisterin",
    "oberbürgermeister",
    "oberbürgermeisterin",

    # Political leadership positions
    "bundeskanzler",
    "bundeskanzlerin",
    "bundestagsvizepräsident",
    "bundestagsvizepräsidentin",
    "bundestagspräsident",
    "bundestagspräsidentin",
    "ministerpräsident",
    "ministerpräsidentin",

    # Ministerial positions
    "minister",
    "ministerin",
    "staatsminister",
    "staatsministerin",
    "staatssekretär",
    "staatssekretärin",

    # Party leadership
    "parteivorsitzender",
    "parteivorsitzende",
    "generalsekretär",
    "generalsekretärin",

    # Other political positions
    "senatorin",
    "senator",
    "landrat",
    "landrätin",
    "fraktionsvorsitzender",
    "fraktionsvorsitzende"
)

# Create a vectorized function to check for legislator patterns and return status
classify_legislator_status <- function(occupations) {
    sapply(occupations, function(x) {
        if (is.na(x)) {
            return("not_legis")
        }

        # Check if the occupation contains any legislator pattern
        has_legislator_pattern <- any(sapply(legislator_patterns, function(pattern) {
            str_detect(x, fixed(pattern, ignore_case = TRUE))
        }))

        # If it doesn't contain a legislator pattern, return "not_legis"
        if (!has_legislator_pattern) {
            return("not_legis")
        }

        # If it contains a comma, it might be "XXX, mdb" format
        # In this case, it's "is_legis" but not "only_legis"
        if (str_detect(x, ",")) {
            return("is_legis")
        }

        # If it has legislator pattern and no comma, it's "only_legis"
        return("only_legis")
    })
}

# Apply the function to mark legislators
cf <- cf %>%
    mutate(
        legislator_status = classify_legislator_status(occupation),
        is_legislator = legislator_status %in% c("is_legis", "only_legis"),
        is_only_legislator = legislator_status == "only_legis"
    )

# Function to extract the specific legislative position
extract_legislative_position <- function(occupations) {
    sapply(occupations, function(x) {
        if (is.na(x)) {
            return(NA_character_)
        }
        for (pattern in legislator_patterns) {
            if (str_detect(x, fixed(pattern, ignore_case = TRUE))) {
                if (str_detect(x, ",")) {
                    parts <- str_split(x, ",")[[1]]
                    for (part in parts) {
                        part <- str_trim(part)
                        if (any(sapply(legislator_patterns, function(p) str_detect(part, fixed(p, ignore_case = TRUE))))) {
                            return(part)
                        }
                    }
                }
                return(x)
            }
        }
        return(NA_character_)
    })
}

# Add column for legislative position
cf <- cf %>%
    mutate(
        legislative_position = extract_legislative_position(occupation)
    )

# Function to remove legislator patterns from occupation titles
remove_legislator_patterns <- function(occupation_text, is_leg) {
    if (!is_leg || is.na(occupation_text)) {
        return(occupation_text)
    }
    cleaned_text <- occupation_text
    for (pattern in legislator_patterns) {
        boundary_pattern <- paste0("\\b", pattern, "\\b")
        cleaned_text <- str_replace_all(cleaned_text, regex(boundary_pattern, ignore_case = TRUE), "")
    }
    cleaned_text <- str_squish(cleaned_text)
    cleaned_text <- str_replace_all(cleaned_text, "\\(\\s*\\)", "")
    cleaned_text <- str_replace_all(cleaned_text, ",\\s*,", ",")
    cleaned_text <- str_replace_all(cleaned_text, "^,\\s*|\\s*,$", "")
    cleaned_text <- str_squish(cleaned_text)
    if (cleaned_text == "") {
        return(NA_character_)
    }
    return(cleaned_text)
}

# Apply the removal function to clean occupation titles
cf <- cf %>%
    mutate(
        occupation = mapply(remove_legislator_patterns, occupation, is_legislator),
        across(starts_with("occ_"), ~ mapply(remove_legislator_patterns, ., is_legislator))
    )

# Validation check: check if legislator patterns still exist in cleaned occupation fields
print("Checking for remaining legislator patterns in cleaned occupation fields...")
validation_check <- cf %>%
    filter(is_legislator) %>%
    select(occupation) %>%
    filter(!is.na(occupation)) %>%
    mutate(has_legislator_term = FALSE)

for (pattern in legislator_patterns) {
    validation_check <- validation_check %>%
        mutate(has_legislator_term = has_legislator_term |
            str_detect(occupation, regex(pattern, ignore_case = TRUE)))
}

if (any(validation_check$has_legislator_term, na.rm = TRUE)) {
    print("WARNING: Some legislator terms were not properly removed!")
    print("Examples of problematic occupation entries:")
    validation_check %>%
        filter(has_legislator_term) %>%
        head(20) %>%
        print()
    print("Frequency of remaining legislator patterns:")
    pattern_counts <- data.frame(pattern = character(), count = integer())
    for (pattern in legislator_patterns) {
        count <- sum(str_detect(validation_check$occupation, regex(pattern, ignore_case = TRUE)), na.rm = TRUE)
        if (count > 0) {
            pattern_counts <- rbind(pattern_counts, data.frame(pattern = pattern, count = count))
        }
    }
    pattern_counts %>%
        arrange(desc(count)) %>%
        print()
} else {
    print("Validation passed: No legislator terms found in cleaned occupation fields.")
}

# Save the processed data
write_rds(cf, "output/prepped_data.rds")

glimpse(cf)
# Also save as CSV with UTF-8 encoding to preserve special characters
write_csv(cf, "output/prepped_data.csv")
