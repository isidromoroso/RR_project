import yfinance as yf
import pandas as pd
import numpy as np

# Load your base dataset and earlier collected missing columns
new_df = pd.read_csv("vas_crude_copaud_new.csv", index_col=0, parse_dates=True)
missing_df = pd.read_csv("missing_columns_data.csv", index_col=0, parse_dates=True)

# Additional tickers to complete missing values
extra_tickers = {
    'cop': 'COP=X',
    'usd': 'DX-Y.NYB',
    'gold': 'GC=F',
    'wti': 'CL=F',
    'brent': 'BZ=F'
}

start_date = new_df.index.min().strftime("%Y-%m-%d")
end_date = new_df.index.max().strftime("%Y-%m-%d")

# Download and safely store extra data
extra_data = {}

for label, symbol in extra_tickers.items():
    print(f"Downloading {label} ({symbol})...")
    try:
        df = yf.download(symbol, start=start_date, end=end_date)
        if not df.empty and ("Adj Close" in df.columns or "Close" in df.columns):
            series = df["Adj Close"] if "Adj Close" in df.columns else df["Close"]
            series.name = label
            extra_data[label] = series
        else:
            print(f"Skipping {label}: no data or missing price column.")
    except Exception as e:
        print(f"Error downloading {label}: {e}")

# Combine valid series into a DataFrame and reindex to match new_df
extra_df = pd.concat(extra_data.values(), axis=1).reindex(new_df.index)

# Merge new base, previous missing data, and extra fetched data
full_df = pd.concat([new_df, missing_df, extra_df], axis=1)

# Add placeholder columns for unavailable variables
for col in ['robusta', 'api2', 'vasconia']:
    if col not in full_df.columns:
        full_df[col] = np.nan

# Drop duplicate columns (keep latest) and sort
full_df = full_df.loc[:, ~full_df.columns.duplicated()]
full_df = full_df.sort_index()

# Save the final dataset
full_df.to_csv("vas_crude_copaud_final.csv")
print("✅ Saved final dataset to vas_crude_copaud_final.csv")
