import yfinance as yf
import pandas as pd

# Define date range
start_date = "2019-01-01"
end_date = "2023-12-31"

# Define tickers for exchange rates and Brent
tickers = {
    'nok': 'NOKJPY=X',
    'usd': 'USDJPY=X',
    'eur': 'EURJPY=X',
    'gbp': 'GBPJPY=X',
    'brent_usd': 'BZ=F'
}

# Download financial series
data = {}
for label, ticker in tickers.items():
    print(f"Downloading {label} ({ticker})...")
    df = yf.download(ticker, start=start_date, end=end_date, auto_adjust=True)
    data[label] = df['Close'] if 'Close' in df.columns else pd.Series(dtype='float64')

# Merge series into one DataFrame
df = pd.concat(data.values(), axis=1)
df.columns = data.keys()
df = df.reset_index()
df['date'] = pd.to_datetime(df['Date']).dt.strftime('%m/%d/%Y')
df['date_dt'] = pd.to_datetime(df['Date'])
df.drop(columns='Date', inplace=True)

# Calculate Brent in JPY
if 'brent_usd' in df and 'usd' in df:
    df['brent'] = df['brent_usd'] * df['usd']
df.drop(columns='brent_usd', inplace=True, errors='ignore')

# Load interest rate data
ir = pd.read_csv("norway_interest_rate_cleaned.csv")
ir['date'] = pd.to_datetime(ir['date'])

# Merge interest rate
df = df.merge(ir, how='left', left_on='date_dt', right_on='date')
df.drop(columns=['date_y'], inplace=True, errors='ignore')
df.rename(columns={'date_x': 'date'}, inplace=True)

# Load GDP YoY data
gdp = pd.read_csv("norway_gdp_yoy_cleaned.csv")
gdp['date'] = pd.to_datetime(gdp['date'])

# Merge GDP YoY without forward fill
df = df.merge(gdp, how='left', left_on='date_dt', right_on='date', suffixes=('', '_gdp'))
df.drop(columns=['date_gdp'], inplace=True, errors='ignore')

# Final cleanup
df.drop(columns=['date_dt'], inplace=True, errors='ignore')

# Reorder columns
df = df[['date', 'nok', 'usd', 'eur', 'gbp', 'brent', 'gdp yoy', 'interest rate']]

# Forward fill every column except gdp yoy that we keep quarterly
df[['nok', 'usd', 'eur', 'gbp', 'brent', 'interest rate']] = df[['nok', 'usd', 'eur', 'gbp', 'brent', 'interest rate']].ffill()

# Save to CSV
df.to_csv("brent crude nokjpy new data.csv", index=False)
print("Final dataset saved to 'brent crude nokjpy new data.csv'")