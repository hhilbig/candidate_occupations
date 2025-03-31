# Required Python packages:
# pip install pandas numpy sentence-transformers openpyxl torch

import re
import os
import pandas as pd
import numpy as np
from sentence_transformers import SentenceTransformer, util

# --- 1. Load Main Data ---

# Load the main dataset (prepped_data.csv)
cf = pd.read_csv("input/prepped_data.csv", encoding="latin1")
print(f"Loaded main dataset with {len(cf)} records.")

# Assume the main file has a column "occupation" (one occupation per row)
# Normalize the occupation strings for matching
cf["occupation_norm"] = cf["occupation"].astype(str).str.lower().str.strip()

# --- 2. Load Preprocessed Occupation & KLDB Data ---

# Load preprocessed occupations (this file should include only unique, cleaned occupation strings)
preproc_occ = pd.read_csv(
    "output/preprocessed_occupations_for_embedding.csv", encoding="latin1"
)
print(f"Loaded {len(preproc_occ)} preprocessed occupation records.")

# Normalize the occupation field in the preprocessed file
preproc_occ["occupation_clean"] = (
    preproc_occ["occupation"].astype(str).str.lower().str.strip()
)

# Drop duplicates so that each occupation appears only once
preproc_occ_unique = preproc_occ.drop_duplicates(subset=["occupation_clean"])

# Load preprocessed KLDB reference data (should contain columns "kldb_title" and "kldb_code5")
kldb = pd.read_csv("output/preprocessed_kldb_for_embedding.csv", encoding="latin1")
print(f"Loaded {len(kldb)} preprocessed KLDB titles.")

# --- 3. Precompute Embeddings & Build Mapping ---

# Use a German-capable model; here we use xlm-roberta-large.
model = SentenceTransformer("xlm-roberta-large")

# File paths for embeddings
occ_embeddings_file = "output/occ_embeddings.npy"
kldb_embeddings_file = "output/kldb_embeddings.npy"

# Compute or load occupation embeddings
if os.path.exists(occ_embeddings_file):
    occ_embeddings = np.load(occ_embeddings_file)
    print("Loaded occupation embeddings from disk.")
else:
    occ_list = preproc_occ_unique["occupation_clean"].tolist()
    occ_embeddings = model.encode(occ_list, batch_size=32, show_progress_bar=True)
    np.save(occ_embeddings_file, occ_embeddings)
    print("Computed and saved occupation embeddings.")

# Compute or load KLDB embeddings
if os.path.exists(kldb_embeddings_file):
    kldb_embeddings = np.load(kldb_embeddings_file)
    print("Loaded KLDB embeddings from disk.")
else:
    kldb_list = kldb["kldb_title"].tolist()
    kldb_embeddings = model.encode(kldb_list, batch_size=32, show_progress_bar=True)
    np.save(kldb_embeddings_file, kldb_embeddings)
    print("Computed and saved KLDB embeddings.")

# For each preprocessed occupation, compute cosine similarity to all KLDB titles
cos_sim_matrix = util.cos_sim(occ_embeddings, kldb_embeddings)
cos_sim_matrix = cos_sim_matrix.cpu().numpy()  # Convert to numpy array

# Get the best match for each preprocessed occupation
best_indices = np.argmax(cos_sim_matrix, axis=1)
best_similarities = np.max(cos_sim_matrix, axis=1)

# Add best-match info to the preprocessed occupations DataFrame
preproc_occ_unique["matched_kldb_code"] = kldb["kldb_code5"].iloc[best_indices].values
preproc_occ_unique["matched_kldb_title"] = kldb["kldb_title"].iloc[best_indices].values
preproc_occ_unique["similarity_score"] = best_similarities

# Build a dictionary mapping each normalized preprocessed occupation to its match info
mapping = preproc_occ_unique.set_index("occupation_clean")[
    ["matched_kldb_code", "matched_kldb_title", "similarity_score"]
].to_dict(orient="index")

# --- 4. Define a Function to Get the Top Match Using Embedding Distance ---

SIMILARITY_THRESHOLD = 0.7  # Adjust this threshold as needed
cache = {}


def get_top_match(occ, threshold=SIMILARITY_THRESHOLD):
    occ_norm = str(occ).lower().strip()
    # If already computed, return from cache
    if occ_norm in cache:
        return cache[occ_norm]
    # If the occupation is in our precomputed mapping, use it
    if occ_norm in mapping:
        res = mapping[occ_norm]
        if res["similarity_score"] < threshold:
            res = {
                "matched_kldb_code": np.nan,
                "matched_kldb_title": np.nan,
                "similarity_score": res["similarity_score"],
            }
        cache[occ_norm] = res
        return res
    # Fallback: compute embedding on the fly (should not occur if all occupations are covered)
    occ_emb = model.encode([occ_norm], show_progress_bar=False)
    cos_sim = util.cos_sim(occ_emb, kldb_embeddings)
    cos_sim_np = cos_sim.cpu().numpy()[0]
    idx = np.argmax(cos_sim_np)
    max_sim = cos_sim_np[idx]
    if max_sim < threshold:
        res = {
            "matched_kldb_code": np.nan,
            "matched_kldb_title": np.nan,
            "similarity_score": max_sim,
        }
    else:
        res = {
            "matched_kldb_code": kldb["kldb_code5"].iloc[idx],
            "matched_kldb_title": kldb["kldb_title"].iloc[idx],
            "similarity_score": max_sim,
        }
    cache[occ_norm] = res
    return res


# --- 5. Apply the Matching Function to the Main Dataset ---

# For each row's occupation, retrieve the best match
cf["matched_kldb_code"] = cf["occupation_norm"].apply(
    lambda x: get_top_match(x)["matched_kldb_code"]
)
cf["matched_kldb_title"] = cf["occupation_norm"].apply(
    lambda x: get_top_match(x)["matched_kldb_title"]
)
cf["similarity_score"] = cf["occupation_norm"].apply(
    lambda x: get_top_match(x)["similarity_score"]
)

# Optionally, remove the helper normalized column
cf.drop(columns=["occupation_norm"], inplace=True)

# --- 6. Save the Final Matched Data ---

cf.to_csv("input/matched_data.csv", index=False)
print("Matching complete. Final data saved to 'input/matched_data.csv'")
