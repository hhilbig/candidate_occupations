# Matching reported candidate occupations to KldB/ISCO categories

MP candidates in Germany self-report occupations in a non-standard format. The goal of this repo is to match these self-reported occupations to the German KldB 2010 classification and the ISCO-08 classification. I use semantic matching using the XLM-RoBERTa-large model, which results in good matches for about half of all unique party-candidate combinations.

**Candidate population:** I use all candidates for the Bundestag (federal parliament) in all elections between 1980 and 2021. Elections prior to 1990 are limited to West Germany. I only use candidates for the SPD, CDU/CSU, FDP, Green, Left (previously PDS) and AfD parties. This data comes directly from the federal returning officer.

**Share candidates with matches:** I use an ad-hoc (based on trial and error) lower bound for match quality to ensure that matches are accurate (see file `src/check_and_save_results.R`). Out of a total of 11,395 unique candidate-party combinations, I obtain good matches for 5,971, about 52%.

**Output data:**

## Sample of non-exact matches

Below is a sample of non-exact matches. The KldB and original reported occupations are already pre-processed, i.e. they are slightly different than in the input data.

| Original occupation | Matched KldB title |
|---------------------|-------------------|
| teammanagerin digitalisierung | team und qualitätsmanagerin |
| medienwissenschaftlerin | medien und filmwissenschaftlerin |
| laborant | laborant analytik |
| grundschullehrerin | grund und hauptschullehrerin |
| prüfstellenleiter | leiter einer baustoffprüfstelle |
| verwaltungsangestellte | verwaltungsangestellte r gehobener dienst |
| kinderkrankenschwester | kinderkrankenschwester pfleger |
| assistenzarzt | assistenzarzt ärztin |
| reisebuerokaufmann | reisende r |
| ingenieurökonomin | ingenieurökonomin bergbau |
| bautechnikerin | bautechnikerin denkmalpflege |
| innenarchitektin diplom | innenarchitektin |
| elektromechaniker | elektro und radiomechaniker |
| allgemeinarzt | allgemeinarzt ärztin |
| fachkraft lagerwirtschaft | fachkraft kreislauf abfallwirtschaft |
| betonbauer | beton und stahlbetonbauer |
| schlossermeister | schlosser und schmiedemeister |
| kraftfahrzeugmeister | kraftfahrzeug industriemeister |
| medizinisch technische radiologieassistentin | medizinisch technische r fachassistentin |
| medizinpädagoge | medizinpädagoge pädagogin |

Some of these matches are likely not fully correct, but even incorrect matches should point towards "similar" occupations in the KldB list.

## Methodology

### Data Processing Pipeline

1. **KldB Data Preparation** (`src/prep_kldb_berufe_data.R`)
   - Converts occupation titles like "Lehrer/in" to separate entries ("Lehrer", "Lehrerin")
   - Standardizes text (removes punctuation, converts to lowercase, expands "Dipl." → "Diplom")
   - Extracts domain information from parenthetical notes

2. **MP Occupation Processing** (`src/prep_mp_occ_data.R`)
   - Splits multiple occupations into separate columns (up to 4 per candidate)
   - Expands abbreviations and normalizes inconsistent reporting patterns
   - Tags legislator-specific roles (e.g., "Mitglied des Bundestages")

3. **Semantic Matching** (`src/embed_match_kldb.py`)
   - Uses XLM-RoBERTa-large to create vector embeddings for occupations
   - Optionally splits German compound words for better matching
   - Matches occupations based on cosine similarity scores

4. **Results Validation** (`src/check_and_save_results.R`)
   - Applies 99.985% similarity threshold for quality control
   - Maps KldB codes to ISCO-08 codes via official conversion tables
   - Analyzes match coverage by election year and party

## Usage

**Input Files:**

- `input/Alphabetisches-Verzeichnis-Berufsbenennungen-Stand01012019.xlsx`: KldB reference list
- `input/Umsteigeschluessel-KLDB2020-ISCO08.xlsx`: KldB to ISCO-08 mapping
- `input/input_data.rds`: MP occupation data
- `input/german/german_utf8.dic`: German dictionary (optional)

**Outputs:**

- `output/unique_occupation_matches.csv`: Matches with similarity scores
- Additional preprocessing files and cached embeddings

**Execution Order:**

1. `src/prep_kldb_berufe_data.R`
2. `src/prep_mp_occ_data.R`
3. `src/embed_match_kldb.py`
4. `src/check_and_save_results.R`
