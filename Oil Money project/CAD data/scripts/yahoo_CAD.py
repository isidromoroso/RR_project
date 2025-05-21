#!/usr/bin/env python3

import pandas as pd
import yfinance as yf


def main():
    # Define date range
    start = '2019-01-01'
    end   = '2023-12-31'

    # Map of output column names to Yahoo Finance tickers
    symbols = {
        'wti':  'CL=F',       # WTI Crude Oil Futures
        'gas':  'NG=F',       # Henry Hub Natural Gas Futures
        'gold': 'GC=F',       # Gold Futures
        'cad':  'CADUSD=X',   # CAD per USD
        'aud':  'AUDUSD=X',   # AUD per USD
        'eur':  'EURUSD=X',   # EUR per USD
        'cny':  'CNYUSD=X',   # CNY per USD
        'mxn':  'MXNUSD=X',   # MXN per USD
        'jpy':  'JPYUSD=X',   # JPY per USD
        'gbp':  'GBPUSD=X',   # GBP per USD
        'krw':  'KRWUSD=X',   # KRW per USD
    }

    # Download each series and collect into a list
    series_list = []
    for col, ticker in symbols.items():
        df = yf.download(ticker, start=start, end=end, auto_adjust=False, progress=False)
        # Select adjusted close if present; otherwise, use close
        if 'Adj Close' in df.columns:
            s = df['Adj Close'].copy()
        else:
            s = df['Close'].copy()
        s.name = col
        series_list.append(s)

    # Combine into one DataFrame and drop any rows with missing values
    df_all = pd.concat(series_list, axis=1).dropna()

    # Reset index: the Date index becomes a column
    df_all = df_all.reset_index().rename(columns={'index':'date', 'Date':'date'})

    # Format date as m/d/YYYY
    df_all['date'] = pd.to_datetime(df_all['date']).dt.strftime('%-m/%-d/%Y')

    # Export to CSV
    df_all.to_csv('cadaud_from_yahoo.csv', index=False)
    print("✅ Saved merged data to cadaud_from_yahoo.csv")

if __name__ == '__main__':
    main()
