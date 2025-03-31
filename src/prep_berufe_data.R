pacman::p_load(tidyverse, readxl)

# Load KLDB reference data from Excel
kldb_reference <- readxl::read_excel(
  "input/Alphabetisches-Verzeichnis-Berufsbenennungen-Stand01012019.xlsx",
  sheet = 2, # second sheet (1-indexed in R)
  skip = 4,
  col_names = c("kldb_title", "kldb_code5")
) %>%
  filter(!is.na(kldb_title))
kldb_reference %>%
  filter(str_detect(kldb_title, "beamte"))

# Normalize KLDB titles and store original values
kldb_reference <- kldb_reference %>%
  mutate(
    original_title = kldb_title, # Store the original title
    kldb_title = tolower(trimws(as.character(kldb_title)))
  )

# Mark rows that have gender notation patterns before we remove punctuation
kldb_reference <- kldb_reference %>%
  mutate(
    has_gender_notation = str_detect(kldb_title, "/in\\b|/-beamtin\\b|/-in\\b|beamte/beamtin")
  )

# Additional text cleaning and normalization
kldb_reference <- kldb_reference %>%
  mutate(
    # Clean the text
    kldb_title = str_replace_all(kldb_title, "[[:punct:]]", " "),
    kldb_title = str_replace_all(kldb_title, "[0-9]", " "),
    kldb_title = str_squish(kldb_title)
  )

# Remove stopwords (create a German stopwords list)
german_stopwords <- c("und", "der", "die", "das", "in", "für", "von", "mit", "bei", "im", "an", "zu", "auf")
kldb_reference <- kldb_reference %>%
  mutate(
    kldb_title = map_chr(kldb_title, function(text) {
      words <- unlist(str_split(text, "\\s+"))
      words <- words[!words %in% german_stopwords]
      paste(words, collapse = " ")
    })
  )

# Lemmatization or stemming (would require additional packages)
# Consider using 'textstem' package for German

# Handle abbreviations and standardize terms
common_abbrev <- c(
  "u\\." = "und",
  "techn\\." = "technisch",
  "ing\\." = "ingenieur",
  "dipl\\." = "diplom"
)

for (pattern in names(common_abbrev)) {
  kldb_reference$kldb_title <- str_replace_all(kldb_reference$kldb_title, pattern, common_abbrev[pattern])
}

# Normalize job categories (optional - depending on your goal)
kldb_reference <- kldb_reference %>%
  mutate(
    category = case_when(
      str_detect(kldb_title, "ingenieur|techniker") ~ "technical",
      str_detect(kldb_title, "verkäufer|berater|kaufmann|kauffrau") ~ "sales",
      str_detect(kldb_title, "lehrer|pädagog") ~ "education",
      # Add more categories as needed
      TRUE ~ "other"
    )
  )

# Handle German gender notation (e.g., "lehrer/in" → add both masculine and feminine forms)
# Create a function to process each title and code pair
process_title <- function(title, code, original_title = NULL, has_gender_notation = FALSE) {
  # If this row has gender notation, use the original title instead of the preprocessed one
  if (has_gender_notation && !is.null(original_title)) {
    # Convert to lowercase for consistency
    original_title <- tolower(original_title)

    # Extract domain information
    domain_info <- ""
    if (grepl("\\(.*\\)", original_title)) {
      domain_info <- str_extract(original_title, "\\(.*\\)")
      domain_info <- str_replace_all(domain_info, "[[:punct:]]", " ")
      domain_info <- str_squish(domain_info)
      original_title <- str_replace(original_title, "\\s*\\(.*\\)", "")
    }

    # Process based on gender pattern
    if (grepl("/in\\b", original_title)) {
      # Pattern: "lehrer/in"
      base_form <- trimws(gsub("/in\\b", "", original_title))
      feminine_form <- trimws(gsub("/in\\b", "in", original_title))

      # Clean these forms
      base_form <- str_replace_all(base_form, "[[:punct:]]", " ")
      feminine_form <- str_replace_all(feminine_form, "[[:punct:]]", " ")
      base_form <- str_squish(base_form)
      feminine_form <- str_squish(feminine_form)

      # Add back domain information if it was present
      if (domain_info != "") {
        base_form <- paste(base_form, domain_info)
        feminine_form <- paste(feminine_form, domain_info)
      }

      return(list(
        tibble(
          kldb_title = c(base_form, feminine_form),
          kldb_code5 = c(code, code)
        )
      ))
    } else if (grepl("beamter/-beamtin", original_title)) {
      # Special case for "beamter/-beamtin" pattern
      base_part <- gsub("(\\w+)beamter/-beamtin.*", "\\1", original_title)

      masculine_form <- trimws(paste0(base_part, "beamter"))
      feminine_form <- trimws(paste0(base_part, "beamtin"))

      # Clean these forms
      masculine_form <- str_replace_all(masculine_form, "[[:punct:]]", " ")
      feminine_form <- str_replace_all(feminine_form, "[[:punct:]]", " ")
      masculine_form <- str_squish(masculine_form)
      feminine_form <- str_squish(feminine_form)

      # Add back domain information if it was present
      if (domain_info != "") {
        masculine_form <- paste(masculine_form, domain_info)
        feminine_form <- paste(feminine_form, domain_info)
      }

      return(list(
        tibble(
          kldb_title = c(masculine_form, feminine_form),
          kldb_code5 = c(code, code)
        )
      ))
    } else if (grepl("ingenieu.*/-in", original_title)) {
      # Special case for "ingenieur/-in" pattern
      masculine_form <- "ingenieur"
      feminine_form <- "ingenieurin"

      # Clean these forms
      masculine_form <- str_replace_all(masculine_form, "[[:punct:]]", " ")
      feminine_form <- str_replace_all(feminine_form, "[[:punct:]]", " ")
      masculine_form <- str_squish(masculine_form)
      feminine_form <- str_squish(feminine_form)

      # Add back domain information if it was present
      if (domain_info != "") {
        masculine_form <- paste(masculine_form, domain_info)
        feminine_form <- paste(feminine_form, domain_info)
      }

      return(list(
        tibble(
          kldb_title = c(masculine_form, feminine_form),
          kldb_code5 = c(code, code)
        )
      ))
    } else if (grepl("beamte/beamtin", original_title)) {
      # Special case for "beamte/beamtin" pattern (without hyphen)
      masculine_form <- "beamter"
      feminine_form <- "beamtin"

      # Clean these forms
      masculine_form <- str_replace_all(masculine_form, "[[:punct:]]", " ")
      feminine_form <- str_replace_all(feminine_form, "[[:punct:]]", " ")
      masculine_form <- str_squish(masculine_form)
      feminine_form <- str_squish(feminine_form)

      # Add back domain information if it was present
      if (domain_info != "") {
        masculine_form <- paste(masculine_form, domain_info)
        feminine_form <- paste(feminine_form, domain_info)
      }

      return(list(
        tibble(
          kldb_title = c(masculine_form, feminine_form),
          kldb_code5 = c(code, code)
        )
      ))
    } else if (grepl("er/-in", original_title)) {
      # Handle patterns like "verkäufer/-in"
      base_part <- gsub("(\\w+)er/-in.*", "\\1", original_title)

      masculine_form <- trimws(paste0(base_part, "er"))
      feminine_form <- trimws(paste0(base_part, "in"))

      # Clean these forms
      masculine_form <- str_replace_all(masculine_form, "[[:punct:]]", " ")
      feminine_form <- str_replace_all(feminine_form, "[[:punct:]]", " ")
      masculine_form <- str_squish(masculine_form)
      feminine_form <- str_squish(feminine_form)

      # Add back domain information if it was present
      if (domain_info != "") {
        masculine_form <- paste(masculine_form, domain_info)
        feminine_form <- paste(feminine_form, domain_info)
      }

      return(list(
        tibble(
          kldb_title = c(masculine_form, feminine_form),
          kldb_code5 = c(code, code)
        )
      ))
    }
  }

  # For rows without gender notation, or if we couldn't process the gender notation,
  # just return the preprocessed title as is
  return(list(
    tibble(
      kldb_title = title,
      kldb_code5 = code
    )
  ))
}

# Use mapply with progress bar
results <- pmap_dfr(
  list(
    kldb_reference$kldb_title,
    kldb_reference$kldb_code5,
    kldb_reference$original_title,
    kldb_reference$has_gender_notation
  ),
  function(title, code, orig, has_gender) {
    process_title(title, code, orig, has_gender)
  },
  .progress = TRUE
)

# Combine all results
expanded_titles <- results
kldb_reference <- expanded_titles

# Display 100 random rows from the results
results %>%
  sample_n(100) %>%
  print(n = 100)

# Create n-grams for multi-word occupational concepts
library(text2vec)
create_ngrams <- function(text, n = 2) {
  words <- unlist(str_split(text, "\\s+"))
  if (length(words) < n) {
    return(text)
  }

  ngrams <- character(length(words) - n + 1)
  for (i in 1:(length(words) - n + 1)) {
    ngrams[i] <- paste(words[i:(i + n - 1)], collapse = "_")
  }

  return(paste(c(words, ngrams), collapse = " "))
}

kldb_reference <- kldb_reference %>%
  mutate(
    text_with_ngrams = map_chr(kldb_title, ~ create_ngrams(.x, n = 2))
  )

# Handle sector/domain information with brackets
kldb_reference <- kldb_reference %>%
  mutate(
    has_domain = str_detect(kldb_title, "\\(.*\\)"),
    domain = str_extract(kldb_title, "(?<=\\().*(?=\\))"),
    clean_title = str_replace(kldb_title, "\\s*\\(.*\\)", "")
  )

# Calculate term frequency statistics
library(text2vec)

# Save preprocessed data for embedding
write_csv(kldb_reference, "output/preprocessed_kldb_for_embedding.csv")
