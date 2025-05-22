import pandas as pd

# 1. Load your merged file
df = pd.read_csv(
    "CAD data/Edmonton Data/"
    "nrcan-edmonton-wcs-daily.csv",
    parse_dates=["date"]
)

# 2. Turn 'date' into your index
df = df.set_index("date")

# 3a. If you want EVERY calendar day:
df = df.asfreq("D")

# 3b. If you’d rather only fill business days (Mon–Fri), instead do:
# df = df.asfreq("B")

# 4. Interpolate linearly in time
df["WCS_CAD_per_m3"] = df["WCS_CAD_per_m3"].interpolate(method="time")

# 5. (Optional) back- or forward-fill any leading/trailing NaNs:
df["WCS_CAD_per_m3"] = df["WCS_CAD_per_m3"].fillna(method="bfill").fillna(method="ffill")

# 6. Write out the result
df.reset_index().to_csv(
    "/Users/jackshephard-thorn/Desktop/RR_Project/Repo/"
    "RR_project/Oil Money project/CAD data/Edmonton Data/"
    "nrcan-edmonton-wcs-daily-interpolated.csv",
    index=False
)
