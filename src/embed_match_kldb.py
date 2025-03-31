# Required Python packages:
# pip install pandas numpy sentence-transformers openpyxl torch

import re
import os
import pandas as pd
import numpy as np
from sentence_transformers import SentenceTransformer, util
from german_compound_splitter import comp_split

# --- 1. Load Main Data ---

# Load the main dataset (prepped_data.csv)
cf = pd.read_csv("output/prepped_data.csv", encoding="utf-8")
print(f"Loaded main dataset with {len(cf)} records.")

# Check for umlauts in main dataset
umlaut_chars = ["ä", "ö", "ü", "ß"]
print("\nChecking umlauts in main dataset:")
for char in umlaut_chars:
    count = sum(
        cf[col].astype(str).str.contains(char, na=False).sum()
        for col in ["occ_1", "occ_2", "occ_3", "occ_4"]
    )
    print(f"Found {count} occurrences of '{char}'")

# Optional: Split compound words
SPLIT_COMPOUNDS = True  # Set this to True to enable compound word splitting
ONLY_NOUNS = True  # Set this to True to only split nouns
MASK_UNKNOWN = True  # Set this to True to mask unknown words

if SPLIT_COMPOUNDS:
    input_file = "input/german/german_utf8.dic"  # Using UTF-8 version of the dictionary
    ahocs = comp_split.read_dictionary_from_file(input_file)


def safe_dissect(word, ahocs):
    """Safely dissect a compound word, returning the original word if no split is found."""
    try:
        results = comp_split.dissect(
            word,
            ahocs,
            make_singular=True,
            only_nouns=ONLY_NOUNS,
            mask_unknown=MASK_UNKNOWN,
        )
        if not results:  # If no split was found
            return word
        # Remove "__unknown__" from results and join with spaces
        results = [r for r in results if r != "__unknown__"]
        if not results:  # If all parts were unknown
            return word
        return " ".join(results).lower()
    except Exception as e:
        print(f"Error processing word '{word}': {str(e)}")
        return word


# Combine all occupation fields (occ_1, occ_2, occ_3, occ_4) into a single list
all_occupations = []
original_occupations = []  # Store original titles
for col in ["occ_1", "occ_2", "occ_3", "occ_4"]:
    # Filter out missing values and add non-empty occupations to the list
    occupations = cf[col].dropna().astype(str)
    occupations = occupations[occupations != "nan"].str.strip()  # Don't lowercase yet

    # Store original titles before any processing
    original_occupations.extend(occupations.tolist())

    # Now lowercase for processing
    occupations = occupations.str.lower()

    # Optionally split compound words
    if SPLIT_COMPOUNDS:
        occupations = occupations.apply(lambda x: safe_dissect(x, ahocs))

    all_occupations.extend(occupations.tolist())

# Create a mapping of processed to original titles
title_mapping = dict(zip(all_occupations, original_occupations))

# Extract unique occupations from all occupation fields
unique_occupations = pd.Series(all_occupations).drop_duplicates().reset_index(drop=True)
print(
    f"Found {len(unique_occupations)} unique occupations across all occupation fields."
)

# --- 2. Load Preprocessed KLDB Data ---

# Load preprocessed KLDB reference data (should contain columns "kldb_title" and "kldb_code5")
kldb = pd.read_csv("output/preprocessed_kldb_for_embedding.csv", encoding="utf-8")
print(f"\nLoaded {len(kldb)} preprocessed KLDB titles.")

# Check for umlauts in KLDB dataset
print("\nChecking umlauts in KLDB dataset:")
for char in umlaut_chars:
    count = kldb["kldb_title"].astype(str).str.contains(char, na=False).sum()
    print(f"Found {count} occurrences of '{char}'")

# Store original KLDB titles
kldb["original_kldb_title"] = kldb["kldb_title"]

# Optionally split compound words in KLDB titles
if SPLIT_COMPOUNDS:
    kldb["kldb_title"] = kldb["kldb_title"].apply(lambda x: safe_dissect(x, ahocs))

# --- 3. Compute Embeddings & Match Occupations to KLDB ---

# Use a German-capable model; here we use xlm-roberta-large.
model = SentenceTransformer("xlm-roberta-large")

# File paths for embeddings
kldb_embeddings_file = "output/kldb_embeddings.npy"

# Compute or load KLDB embeddings
if os.path.exists(kldb_embeddings_file):
    kldb_embeddings = np.load(kldb_embeddings_file)
    print("Loaded KLDB embeddings from disk.")
else:
    kldb_list = kldb["kldb_title"].tolist()
    kldb_embeddings = model.encode(kldb_list, batch_size=32, show_progress_bar=True)
    np.save(kldb_embeddings_file, kldb_embeddings)
    print("Computed and saved KLDB embeddings.")

# Encode unique occupations from the combined occupation fields
print("Computing embeddings for unique occupations...")
occ_list = unique_occupations.tolist()
occ_embeddings = model.encode(occ_list, batch_size=32, show_progress_bar=True)

# Compute cosine similarity between occupations and KLDB titles
print("Computing similarity matrix...")
cos_sim_matrix = util.cos_sim(occ_embeddings, kldb_embeddings)
cos_sim_matrix = cos_sim_matrix.cpu().numpy()  # Convert to numpy array

# Get the best match for each occupation
best_indices = np.argmax(cos_sim_matrix, axis=1)
best_similarities = np.max(cos_sim_matrix, axis=1)

# Create a dataframe with the matching results
matching_results = pd.DataFrame(
    {
        "occupation": unique_occupations,
        "original_occupation": [title_mapping[occ] for occ in unique_occupations],
        "matched_kldb_code": kldb["kldb_code5"].iloc[best_indices].values,
        "matched_kldb_title": kldb["kldb_title"].iloc[best_indices].values,
        "original_matched_kldb_title": kldb["original_kldb_title"]
        .iloc[best_indices]
        .values,
        "similarity_score": best_similarities,
    }
)

# Sort by similarity score (descending) to see best matches first
matching_results = matching_results.sort_values(by="similarity_score", ascending=False)

# --- 4. Save the Unique Occupation Matching Results ---
matching_results.to_csv(
    "output/unique_occupation_matches.csv", index=False, encoding="utf-8"
)
print("Matching complete. Results saved to 'output/unique_occupation_matches.csv'")
