# Load required libraries
library(readr)
library(knitr)
library(dplyr)

# Read the CSV file
matches <- read_csv("output/matches_sample.csv")

# Create a nicely formatted markdown table
# Add a header with information about the data
cat("# Sample of MP Occupation Matches\n\n")
cat("This table shows a sample of matches between self-reported MP occupations and KldB categories.\n\n")

# Format the similarity score to 2 decimal places
matches <- matches %>%
    mutate(similarity_score = round(similarity_score, 2))

# Select the first 20 rows for display (adjust as needed)
sample_matches <- head(matches, 20)

# Create and display the markdown table
kable(sample_matches,
    col.names = c(
        "Processed Occupation", "Original Occupation", "KldB Code",
        "Matched KldB Title", "Original KldB Title", "Similarity Score"
    ),
    format = "markdown"
)

# Save as markdown file
sink("matches_sample.md")
cat("# Sample of MP Occupation Matches\n\n")
cat("This table shows a sample of matches between self-reported MP occupations and KldB categories.\n\n")
kable(sample_matches,
    col.names = c(
        "Processed Occupation", "Original Occupation", "KldB Code",
        "Matched KldB Title", "Original KldB Title", "Similarity Score"
    ),
    format = "markdown"
)
sink()

cat("\nMarkdown table has been saved to 'matches_sample.md'\n")
