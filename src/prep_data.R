pacman::p_load(tidyverse, haschaR, readxl, stringi)

# Get the data

cf <- read_rds("input/input_data.rds") %>%
    dplyr::select(1:14) %>%
    mutate(occupation = str_squish(occupation)) %>%
    mutate(occupation = stringi::stri_trans_tolower(occupation))

# Explore the occupation data first
# Check column names
print("Column names in the dataset:")
print(colnames(cf))

# Look at the most common occupations
print("Top 300 most common occupations:")
cf %>%
    count(occupation, sort = TRUE) %>%
    head(300) %>%
    print()

# Check for patterns of multiple occupations
print("Examples of occupations with 'und':")
cf %>%
    filter(str_detect(occupation, "und")) %>%
    select(occupation) %>%
    head(300) %>%
    print()

print("Examples of occupations with commas:")
cf %>%
    filter(str_detect(occupation, ",")) %>%
    select(occupation) %>%
    head(300) %>%
    print()

# Check for legislator patterns
print("Examples of potential legislator occupations:")
legislator_keywords <- c("bundestag", "landtag", "mdb", "mdl", "abgeordnet")
cf %>%
    filter(if_any(occupation, ~ str_detect(., paste(legislator_keywords, collapse = "|")))) %>%
    select(occupation) %>%
    head(20) %>%
    print()

# Count NA and empty values
print(paste("Number of NA occupation values:", sum(is.na(cf$occupation))))
print(paste("Number of empty occupation values:", sum(cf$occupation == "", na.rm = TRUE)))

# Steps:
# 1. Separate multiple occupations (which are divided eg by "," or "und"). we can create new columns for each separated occupation (occ_1, occ_2, etc.). you can check what the maximum number of occupations is and then use that number to create the new columns. they can by NA for people with only one occupation.
# 2. Mark all occupations that *only* refere to the fact that they are MPs or other type of legislator (ie. "mitglied des deutschen bundestages", "mdb", "mitglied des landtages"). could be done using a new variable (legislator = TRUE)

# Step 1: Separate multiple occupations
# First, replace "und" with a comma to standardize separators
cf <- cf %>%
    mutate(occupation = str_replace_all(occupation, " und ", ", "))

# Split occupations by comma and convert to long format to count max number
occupations_split <- cf %>%
    filter(!is.na(occupation)) %>%
    mutate(id = row_number()) %>%
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
    # Fix umlauts in common words (if needed)
    mutate(occupation = str_replace_all(occupation, "buergermeister", "bürgermeister")) %>%
    mutate(occupation = str_replace_all(occupation, "praesident", "präsident")) %>%
    # Remove parenthetical qualifications that don't add occupation information
    mutate(occupation = str_replace_all(occupation, "\\([^)]*\\)", "")) %>%
    # Standardize inconsistent occupational titles
    mutate(occupation = str_replace_all(occupation, "\\bargbeordnete[r]?\\b", "abgeordnete")) %>%
    # Consistent formatting for "selbständig" variations
    mutate(occupation = str_replace_all(occupation, "selbständige[r]? ", "selbständig ")) %>%
    # Additional text cleaning and normalization from prep_berufe_data.R
    mutate(
        occupation = str_replace_all(occupation, "[[:punct:]]", " "), # Remove punctuation
        occupation = str_replace_all(occupation, "[0-9]", " "), # Remove numbers
        occupation = str_squish(occupation) # Remove extra whitespace
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
    separate_rows(occupation, sep = ", ") %>%
    filter(occupation != "") %>%
    mutate(occupation = str_squish(occupation))

# Count maximum number of occupations per person
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

# Join back to the original data
cf <- cf %>%
    mutate(id = row_number()) %>%
    left_join(cf_wide, by = "id") %>%
    select(-id)

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
    "diplomat",
    "senatorin",
    "senator",
    "landrat",
    "landrätin",
    "fraktionsvorsitzender",
    "fraktionsvorsitzende"
)

# Create a properly vectorized function to check for legislator patterns
is_only_legislator <- function(occupations) {
    sapply(occupations, function(x) {
        if (is.na(x)) {
            return(FALSE)
        }

        # Check if the occupation matches any legislator pattern
        matches <- sapply(legislator_patterns, function(pattern) {
            str_detect(x, fixed(pattern, ignore_case = TRUE))
        })

        return(any(matches))
    })
}

# Apply the function to mark legislators
cf <- cf %>%
    mutate(
        is_legislator = is_only_legislator(occupation),
        is_only_legislator = is_legislator & !sapply(occupation, function(x) {
            if (is.na(x)) {
                return(FALSE)
            }

            # First check if it's a legislator
            is_leg <- any(sapply(legislator_patterns, function(pattern) {
                str_detect(x, fixed(pattern, ignore_case = TRUE))
            }))

            if (!is_leg) {
                return(FALSE)
            }

            # Then check if it contains non-legislator occupations
            other_occupations <- TRUE

            # Check common non-legislator occupation patterns
            non_leg_patterns <- c(
                "rechtsanwalt", "anwalt", "jurist", "lehrer", "professor", "arzt", "architekt",
                "ingenieur", "kaufmann", "unternehmer", "landwirt", "betriebswirt",
                "historiker", "politologe", "soziologe", "informatiker"
            )

            contains_other <- any(sapply(non_leg_patterns, function(pattern) {
                str_detect(x, fixed(pattern, ignore_case = TRUE))
            }))

            return(!contains_other)
        })
    )

# Function to extract the specific legislative position
extract_legislative_position <- function(occupations) {
    sapply(occupations, function(x) {
        if (is.na(x)) {
            return(NA_character_)
        }

        # Check each pattern
        for (pattern in legislator_patterns) {
            if (str_detect(x, fixed(pattern, ignore_case = TRUE))) {
                # For occupations with multiple roles, extract the legislative one
                if (str_detect(x, ",")) {
                    parts <- str_split(x, ",")[[1]]
                    for (part in parts) {
                        part <- str_trim(part)
                        if (any(sapply(legislator_patterns, function(p) str_detect(part, fixed(p, ignore_case = TRUE))))) {
                            return(part)
                        }
                    }
                }
                return(x) # Return full occupation if can't isolate just the legislative part
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
    # Only process entries marked as legislators
    if (!is_leg || is.na(occupation_text)) {
        return(occupation_text)
    }

    # Create a clean version by removing all legislator patterns
    cleaned_text <- occupation_text
    for (pattern in legislator_patterns) {
        # Add word boundaries to ensure we only match whole words
        boundary_pattern <- paste0("\\b", pattern, "\\b")
        cleaned_text <- str_replace_all(cleaned_text, regex(boundary_pattern, ignore_case = TRUE), "")
    }

    # Clean up any trailing punctuation and whitespace
    cleaned_text <- str_squish(cleaned_text)
    # Remove empty parentheses that might be left after cleaning
    cleaned_text <- str_replace_all(cleaned_text, "\\(\\s*\\)", "")
    # Remove comma sequences that might be left (e.g., ", ,")
    cleaned_text <- str_replace_all(cleaned_text, ",\\s*,", ",")
    # Clean up leading/trailing commas
    cleaned_text <- str_replace_all(cleaned_text, "^,\\s*|\\s*,$", "")
    # Final squish to clean up whitespace
    cleaned_text <- str_squish(cleaned_text)

    # If the result is empty, return NA
    if (cleaned_text == "") {
        return(NA_character_)
    }

    return(cleaned_text)
}

# Apply the removal function to clean occupation titles
cf <- cf %>%
    mutate(
        # Clean the main occupation field
        occupation = mapply(remove_legislator_patterns, occupation, is_legislator),
        # Also clean the individual occupation columns
        across(starts_with("occ_"), ~ mapply(
            remove_legislator_patterns,
            .,
            is_legislator
        ))
    )

# Save the processed data
write_rds(cf, "input/prepped_data.rds")

# Also save as csv with UTF-8 encoding to preserve umlauts
write_csv(cf, "input/prepped_data.csv", na = "")
