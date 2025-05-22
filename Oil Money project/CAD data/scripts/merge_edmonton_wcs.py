import pandas as pd

# 1) Paths to your two files
main_fp   = "CAD data/daily_with_interpolated_wcs.csv"
edm_fp    = "CAD data/Edmonton Data/nrcan-edmonton-wcs-daily-interpolated.csv"
output_fp = "CAD data/merged_with_edmonton.csv"

# 2) Load and parse dates
df_main = pd.read_csv(main_fp, parse_dates=["date"])
df_edm  = pd.read_csv(edm_fp,  parse_dates=["date"])

# 3) Rename the Edmonton price column to 'edmonton'
#    (replace 'WCS_CAD_per_m3' below with whatever your column is actually called)
df_edm = df_edm.rename(columns={"WCS_CAD_per_m3": "edmonton"})

# 4) Merge on date
df_merged = pd.merge(
    df_main,
    df_edm[["date", "edmonton"]],
    on="date",
    how="left"
)

# 5) Write out
df_merged.to_csv(output_fp, index=False)
print("→ Written merged file to", output_fp)
