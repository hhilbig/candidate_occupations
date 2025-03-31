# MP Occupation Mapping to KLDB and ISCO

This repository contains tools for mapping non-standard occupation descriptions of German MPs to standardized occupation classification systems: first to KLDB (German Classification of Occupations) and subsequently to ISCO (International Standard Classification of Occupations).

## Project Goal

The primary goal is to standardize diverse occupation descriptions into internationally recognized classification codes, enabling consistent analysis and comparison of political representatives' professional backgrounds.

## Methodology

### Data Processing Pipeline

1. **KLDB Data Preparation** (`src/prep_kldb_berufe_data.R`)
   - Loads and preprocesses KLDB reference data from Excel, handling German gender notation patterns, text normalization, and domain information extraction.

2. **MP Occupation Processing** (`src/prep_mp_occ_data.R`)
   - Processes raw MP occupation data, handling multiple occupations per MP, expanding abbreviations, and identifying legislator-only occupations.

3. **KLDB Matching** (`src/embed_match_kldb.py`)
   - Performs semantic matching using XLM-RoBERTa-large model, with optional compound word splitting and similarity scoring.

4. **Results Validation** (`src/check_results.R`)
   - Reviews matching results and assesses match quality through similarity score analysis.

## Technical Implementation

The pipeline implements several key features:

- German-specific text processing including gender notation patterns and compound word splitting
- Advanced text normalization with abbreviation expansion and status indicator removal
- Semantic matching using XLM-RoBERTa-large model with precomputed embeddings
- Multi-occupation handling with confidence scoring for matches

## Usage

The pipeline processes the following files:

Input:

- `input/Alphabetisches-Verzeichnis-Berufsbenennungen-Stand01012019.xlsx`: KLDB reference data
- `input/input_data.rds`: Raw MP occupation data
- `input/german/german_utf8.dic`: German dictionary for compound splitting (optional)

Output:

- `output/preprocessed_kldb_for_embedding.csv`: Processed KLDB data
- `output/unique_occupation_matches.csv`: Matching results with similarity scores

All matches are stored with confidence scores for quality assessment.
