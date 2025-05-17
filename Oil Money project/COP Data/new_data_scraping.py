import yfinance as yf
import pandas as pd

# Define tickers and labels
tickers = {
    'CL=F': 'wti',
    'BZ=F': 'brent',
    'GC=F': 'gold',
    'COP=X': 'cop',
    'BRL=X': 'brl',
    'MXN=X': 'mxn',
    'DX-Y.NYB': 'usd'
}

# Date range
start_date = "2019-01-01"
end_date = "2023-12-31"

# Collect data
data = []

for symbol, label in tickers.items():
    print(f"Downloading {label} ({symbol})...")
    try:
        df = yf.download(symbol, start=start_date, end=end_date)
        if not df.empty:
            # Use 'Adj Close' if available, otherwise 'Close'
            if "Adj Close" in df.columns:
                series = df["Adj Close"]
            elif "Close" in df.columns:
                series = df["Close"]
            else:
                print(f"Skipping {label}: no Close or Adj Close column")
                continue

            series.name = label  # Set the series name
            data.append(series)
        else:
            print(f"Skipping {label}: empty data")
    except Exception as e:
        print(f"Skipping {label} due to error: {e}")

# Combine into DataFrame
if data:
    combined_df = pd.concat(data, axis=1)
    combined_df.dropna(inplace=True)
    combined_df.to_csv("vas_crude_copaud_new.csv")
    print("Data saved to vas_crude_copaud_new.csv")
else:
    print("No valid data to save.")
