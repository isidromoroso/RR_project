import yfinance as yf
import pandas as pd
import time

# Date range
start_date = "2019-01-01"
end_date = "2023-12-31"

# Raw tickers to download
tickers = {
    'cop': 'COP=X',   # No direct AUD/COP available
    'usd': 'AUDUSD=X',
    'cny': 'AUDCNY=X',
    'mxn': 'AUDMXN=X',
    'brl': 'AUDBRL=X',
    'ars': 'AUDARS=X',
    'gold': 'GC=F',
    'arabica': 'KC=F',
    'api2': 'MTF=F',
    'wti': 'CL=F',
    'brent': 'BZ=F',
    'pen_usd': 'PEN=X',   # USD/PEN
    'try_usd': 'TRY=X',   # USD/TRY
    'aud_usd': 'AUDUSD=X' # Needed to compute synthetic crosses
}

# Data download
data = {}
for label, ticker in tickers.items():
    print(f"Downloading {label.upper()} ({ticker})...")
    try:
        df_ticker = yf.download(ticker, start=start_date, end=end_date, auto_adjust=True)
        if not df_ticker.empty and 'Close' in df_ticker.columns:
            data[label] = df_ticker['Close']
        else:
            print(f"No 'Close' data for {label}, skipping.")
            data[label] = pd.Series(dtype='float64')
    except Exception as e:
        print(f"Error downloading {label}: {e}")
        data[label] = pd.Series(dtype='float64')
    
    time.sleep(1)  # Pause to avoid rate limits

# Combine into a single DataFrame
df = pd.concat(data.values(), axis=1)
df.columns = data.keys()
df = df.reset_index()

# Format date
df['date'] = pd.to_datetime(df['Date']).dt.strftime('%m/%d/%Y')
df.drop(columns='Date', inplace=True, errors='ignore')

# Generate synthetic AUD/PEN and AUD/TRY
# AUD/PEN = AUD/USD ÷ USD/PEN
if 'aud_usd' in df.columns and 'pen_usd' in df.columns:
    df['pen'] = df['aud_usd'] / df['pen_usd']

if 'aud_usd' in df.columns and 'try_usd' in df.columns:
    df['try'] = df['aud_usd'] / df['try_usd']

# Rename or add robusta/vasconia placeholders (no unique tickers)
df['robusta'] = df['arabica']  # Placeholder
df['vasconia'] = df['wti']     # Placeholder

# Select and order columns
final_cols = ['date', 'cop','usd', 'cny', 'try', 'mxn', 'brl', 'pen', 'ars',
              'gold', 'arabica', 'robusta', 'api2', 'wti', 'brent', 'vasconia']

# Keep only existing columns
final_cols = [col for col in final_cols if col in df.columns]
df = df[final_cols]

# Forward fill missing values
df[final_cols[1:]] = df[final_cols[1:]].ffill()

# Drop initial row if it contains NaNs
df = df.dropna().reset_index(drop=True)

# 🔁 Invert selected exchange rates
inverse_cols = ['cop', 'usd', 'cny', 'mxn', 'brl', 'ars']
for col in inverse_cols:
    if col in df.columns:
        df[col] = 1 / df[col]

# Show and save
print(df.head())
df.to_csv("COP data/vas_crude_copaud_new_data.csv", index=False)