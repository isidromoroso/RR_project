import pandas as pd

# Load the new scraped file
df = pd.read_csv("vas_crude_copaud_new.csv", index_col=0, parse_dates=True)

# Rename Yahoo tickers to match original short names
rename_map = {
    'CL=F': 'wti',
    'BZ=F': 'brent',
    'GC=F': 'gold',
    'COP=X': 'cop',
    'BRL=X': 'brl',
    'MXN=X': 'mxn',
    'DX-Y.NYB': 'usd'
}

df = df.rename(columns=rename_map)

# Save with updated column names
df.to_csv("vas_crude_copaud_renamed.csv")
print("✅ Saved renamed file as vas_crude_copaud_renamed.csv")
