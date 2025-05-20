import pandas as pd

# Load both files
main_df = pd.read_csv("vas_crude_copaud_renamed.csv", index_col=0, parse_dates=True)
missing_df = pd.read_csv("missing_columns_data.csv", index_col=0, parse_dates=True)

# Merge on index (date)
merged_df = pd.merge(main_df, missing_df, left_index=True, right_index=True, how='inner')

# Save the final merged file
merged_df.to_csv("vas_crude_copaud_merged.csv")

print("✅ Saved merged dataset to vas_crude_copaud_merged.csv")

