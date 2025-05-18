import pandas as pd

# Load GDP data
df = pd.read_csv("norway_real_gdp.csv") # Source FRED: https://fred.stlouisfed.org/series/CLVMNACSCAB1GQNO

# Convert dates
df['observation_date'] = pd.to_datetime(df['observation_date'])

# Rename columns for clarity
df = df.rename(columns={
    'observation_date': 'date',
    'CLVMNACSCAB1GQNO': 'real_gdp'
})

# Sort and calculate GDP YoY %
df = df.sort_values('date')
df['gdp yoy'] = df['real_gdp'].pct_change(periods=4) * 100  # 4 quarters = 1 year

# Drop rows without YoY change (first 4)
df = df.dropna(subset=['gdp yoy'])

# Keep only necessary columns
df = df[['date', 'gdp yoy']]

# Save to CSV
df.to_csv("norway_gdp_yoy_cleaned.csv", index=False)
print("Cleaned GDP YoY data saved to 'norway_gdp_yoy_cleaned.csv'")
