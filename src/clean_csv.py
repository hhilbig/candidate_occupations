import pandas as pd

# Read the CSV file
df = pd.read_csv("output/prepped_data.csv", encoding="utf-8")

# Clean up column names
df.columns = df.columns.str.strip()

# Clean up string columns
for col in df.select_dtypes(include=["object"]).columns:
    df[col] = df[col].str.strip()

# Save the cleaned CSV
df.to_csv("output/prepped_data_clean.csv", index=False, encoding="utf-8")
print("Cleaned CSV saved to output/prepped_data_clean.csv")
