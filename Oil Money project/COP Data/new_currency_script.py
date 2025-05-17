import yfinance as yf
import pandas as pd

# Mapping of missing variables to Yahoo Finance tickers
ticker_map = {
    'cny': 'CNY=X',
    'ars': 'ARS=X',
    'pen': 'PEN=X',
    'try': 'TRY=X',
    'arabica': 'KC=F',
    'robusta': 'RC=F'  # Known to fail
}

start_date = "2019-01-01"
end_date = "2023-12-31"

# Download available data
data = []

for label, symbol in ticker_map.items():
    print(f"Downloading {label} ({symbol})...")
    try:
        df = yf.download(symbol, start=start_date, end=end_date)
        if not df.empty:
            if "Adj Close" in df.columns:
                series = df["Adj Close"]
            elif "Close" in df.columns:
                series = df["Close"]
            else:
                print(f"Skipping {label}: no usable price column.")
                continue
            series.name = label
            data.append(series)
        else:
            print(f"No data returned for {label}")
    except Exception as e:
        print(f"Skipping {label} due to error: {e}")

# Combine valid series
if data:
    missing_data_df = pd.concat(data, axis=1)
    missing_data_df.dropna(inplace=True)
    missing_data_df.to_csv("missing_columns_data.csv")
    print("Saved missing_columns_data.csv")
else:
    print("No valid data to save.")
