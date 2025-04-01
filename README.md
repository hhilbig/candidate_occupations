# Matching reported Bundestag candidate occupations to KldB/ISCO categories

Candidates for the *Bundestag* in Germany self-report occupations in a non-standard format. The goal of this repo is to match these self-reported occupations to the German KldB 2010 classification and the ISCO-08 classification using semantic matching with the XLM-RoBERTa-large model.

**Candidate population:** I use all candidates (list and district) for the Bundestag (federal parliament) in all elections between 1980 and 2021. Elections prior to 1990 are limited to West Germany. I only use candidates for the SPD, CDU/CSU, FDP, Green, Left (previously PDS) and AfD parties. This data comes directly from the federal returning officer.

**Share candidates with matches:** I use an ad-hoc (based on trial and error) lower bound for match quality to ensure that matches are accurate (see file `src/check_and_save_results.R`). Out of a total of 18,352 unique candidate-party combinations, I obtain good matches for 9,105, about 49.61%.

**Output data:** The output data `candidates_with_occupations.csv` is in long format. Rows are combinations of candidate name, party, election year and numbered candidate occupation.

- Some candidates list more than one occupation, which is why some candidate-party-election combinations appear in the data more than once.
- Multiple matches: The official KldB-ISCO crosswalk sometimes maps one KldB code to multiple ISCO codes (up to five). To accommodate this, the output data file `candidates_with_occupations.csv` has five columns for matching ISCO-08 codes (`isco08_code_1` to `isco08_code_5`). Many KldB codes only map to one ISCO-08 code, which is why the latter columns are frequently missing.

**Output data format:**

The output data has the following variables:

| Variable                        | Description                                                                                                  |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `full_name`                   | Candidate's full name                                                                                        |
| `party`                       | Political party of the candidate                                                                             |
| `elec_year`                   | Election year                                                                                                |
| `cand_id`                     | Unique candidate identifier, based on full_name, party, year and candidate occurrence                        |
| `occupation_number`           | Number of the occupation (candidates can have multiple occupations)                                          |
| `occupation`                  | Self-reported occupation of the candidate                                                                    |
| `original_matched_kldb_title` | The KldB occupation title that was matched to the candidate's occupation                                     |
| `matched_kldb_code`           | The KldB classification code for the matched occupation                                                      |
| `isco08_code_1`               | First ISCO-08 code corresponding to the KldB code                                                            |
| `isco08_code_2`               | Second ISCO-08 code (if the KldB code maps to multiple ISCO codes)                                           |
| `isco08_code_3`               | Third ISCO-08 code (if applicable)                                                                           |
| `isco08_code_4`               | Fourth ISCO-08 code (if applicable)                                                                          |
| `isco08_code_5`               | Fifth ISCO-08 code (if applicable)                                                                           |
| `list_state`                  | Federal state for candidates who are on party lists                                                          |
| `list_rank`                   | Candidate's position on the party list                                                                       |
| `elec_district`               | Electoral district where the candidate runs, for district candidates                                         |
| `direct_cand`                 | Indicates if the candidate runs directly in a district                                                       |
| `list_cand`                   | Indicates if the candidate appears on a party list                                                           |
| `is_legislator`               | Indicates if the candidate reports a legislative position, or other elected position in the occupation field |
| `is_only_legislator`          | Indicates if the candidate reports only legislative or other elected position                                |
| `is_duplicated_cand`          | Indicates if the candidate-party-election appears more than once in the dataset                              |

**Other info:**

- Some candidates only list legislative or other related positions (for a full list, see `src/prep_mp_occ_data.R`). There are two flag variables in such cases (`is_legislator` and `is_only_legislator`). This often means that there is no occupation listed, even if these candidates had "regular" jobs before becoming legislators or other types of elected officials. Instead of their regular occupations, some candidates list only a legislative or related occupation. To assign these MPs their regular job, one could track the candidates across all elections in which they compete, and look for an election in which they do list a regular job. For example, a sitting MP may list "Mitglied des Bundestags" after being elected once, but not in the first election they compete in. However, this is currently not implemented, and may also not work in some cases since spelling of MP names is not always consistent.
- I construct a unique `cand_id` (name-party-year-occurrence) to handle rare duplicate entries based on name, party, and year alone.
- The rate of good matches is relatively constant over time, i.e. for all elections it is usually close to 50%.

## Sample of non-exact matches

Below is a sample of non-exact matches, showing the candidate's reported occupation and the matched KldB title *after* text preprocessing steps within the pipeline:

| Original occupation                    | Matched KldB title                             |
| -------------------------------------- | ---------------------------------------------- |
| leiter digitales marketing             | leiter controlling                             |
| maschinenführer                        | maschinen und anlagenführer                    |
| referent                               | referent bildung                               |
| kaufmann                               | kaufmann frau außenhandel                      |
| rechtsanwaltsfachangestellte          | rechtsanwalts und notarfachangestellte r       |
| arzt laboratoriumsmedizin             | arzt ärztin laboratoriumsmedizin              |
| personalrat                            | personalrat rätin                              |
| sozialpädagogischer berater           | sozialpädagogischeer assistent                |
| fachbereichsleiterin                   | fachbereichsleiterin gesamtschulen            |
| flugkapitän i r                        | flugkapitän                                    |
| katholischer gemeindereferent          | katholischeer gemeindereferent                |
| facharzt kinderheilkunde              | facharzt ärztin augenheilkunde                |
| akademischer oberrat                   | akademische r oberrat rätin hochschule        |
| kulturgeografin master of arts         | kulturgeografin                                |
| agrar ingenieur                        | agrartechnischeer assistent                    |

Some of these matches are likely not fully correct, but even incorrect matches should point towards "similar" occupations in the KldB list.

## Data Processing Pipeline

1. **KldB Data Preparation** ([`src/prep_kldb_berufe_data.R`](src/prep_kldb_berufe_data.R))

   - Converts occupation titles like "Lehrer/in" to separate entries ("Lehrer", "Lehrerin")
   - Standardizes text (removes punctuation, converts to lowercase, expands "Dipl." → "Diplom", removes stopwords)
   - Extracts domain information from parenthetical notes
   - Saves preprocessed KldB data to a CSV file for the next step
2. **MP Occupation Processing** ([`src/prep_mp_occ_data.R`](src/prep_mp_occ_data.R))

   - Splits multiple occupations into separate columns (dynamically determined number per candidate)
   - Expands abbreviations (e.g., "Dipl." → "Diplom", "MdB" → "Mitglied des Bundestages")
   - Normalizes text by fixing common umlaut representations (e.g., `ae` → `ä`), removing status indicators (e.g., "a.d.", "i.r."), removing stopwords, and standardizing variants. Parenthetical content is preserved. Most punctuation is removed *after* splitting occupations by comma.
   - Tags over 30 different legislator-specific roles and elected positions
   - Saves preprocessed MP occupation data to a CSV file for the next step
3. **Semantic Matching** ([`src/embed_match_kldb.py`](src/embed_match_kldb.py))

   - Reads preprocessed KldB and MP occupation data from CSV files
   - Uses XLM-RoBERTa-large to create vector embeddings for occupations
   - Splits German compound words using `german_compound_splitter` to improve matching
   - Matches occupations based on cosine similarity scores
   - Caches embeddings to avoid recomputation (note that cached embeddings are not part of the repo)
4. **Results Validation** ([`src/check_and_save_results.R`](src/check_and_save_results.R))

   - Maps KldB codes to ISCO-08 codes via official conversion tables
   - Filters matches based on a similarity score threshold (determined via trial-and-error)
   - Analyzes match coverage by election year and party, saving coverage statistics
   - Saves final output dataset

## Usage

**Input Files:**

- [`input/Alphabetisches-Verzeichnis-Berufsbenennungen-Stand01012019.xlsx`](input/Alphabetisches-Verzeichnis-Berufsbenennungen-Stand01012019.xlsx): KldB reference list
- [`input/Umsteigeschluessel-KLDB2020-ISCO08.xlsx`](input/Umsteigeschluessel-KLDB2020-ISCO08.xlsx): KldB to ISCO-08 mapping
- [`input/candidates_all_80_21.rds`](input/candidates_all_80_21.rds): MP occupation data (Note: This is the source file used by the scripts)
- [`input/german/german_utf8.dic`](input/german/german_utf8.dic): German dictionary (optional)

**Outputs:**

- [`output/candidates_with_occupations.csv`](output/candidates_with_occupations.csv): Final dataset with matched occupations and ISCO codes
- [`output/unique_occupation_matches.csv`](output/unique_occupation_matches.csv): Matches with similarity scores
- Additional preprocessing files (intermediate CSVs generated by R scripts)

**Execution Order:**

1. [`src/prep_kldb_berufe_data.R`](src/prep_kldb_berufe_data.R)
2. [`src/prep_mp_occ_data.R`](src/prep_mp_occ_data.R)
3. [`src/embed_match_kldb.py`](src/embed_match_kldb.py)
4. [`src/check_and_save_results.R`](src/check_and_save_results.R)

**Requirements:**

- Python dependencies: sentence-transformers, pandas, numpy, german_compound_splitter
- R packages: tidyverse, readxl, text2vec, haschaR
