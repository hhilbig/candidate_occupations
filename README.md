# MP Occupation Mapping to KLDB and ISCO

This repository contains tools for mapping non-standard occupation descriptions of German MPs to standardized occupation classification systems: first to KLDB (German Classification of Occupations) and subsequently to ISCO (International Standard Classification of Occupations).

## Project Goal

The primary goal is to standardize diverse occupation descriptions into internationally recognized classification codes, enabling consistent analysis and comparison of political representatives' professional backgrounds.

## Methodology

### Data Processing Pipeline

1. **Data Preparation**
   - Raw MP occupation data is loaded and normalized
   - Text cleaning and standardization of occupation strings

2. **KLDB Matching**
   - Embedding-based semantic matching using sentence transformers
   - Utilizes `xlm-roberta-large` model for generating text embeddings
   - Computes cosine similarity between occupation descriptions and KLDB titles

3. **ISCO Mapping** (subsequent step)
   - Maps KLDB codes to ISCO international classification system

## Technical Implementation

### Cleaning Steps

- String normalization (lowercase, whitespace trimming)
- Precomputing of embeddings for efficiency
- Deduplication of occupation descriptions

### Similarity Calculation

- Sentence embeddings are generated for both MP occupations and KLDB occupation titles
- Cosine similarity matrix computation between all occupation pairs
- Best matches identified through maximum similarity scores
- Configurable similarity threshold (default: 0.7) for match confidence

## Usage

The pipeline consists of:

1. Data preparation scripts
2. Embedding and matching code
3. Output processing for analysis

All matches are stored with confidence scores for quality assessment.
