#!/usr/bin/env python3
import pandas as pd
import yfinance as yf

# ——— EDIT THIS to your actual merged-Edmonton CSV ———
CSV_PATH = (
    "/Users/jackshephard-thorn/Desktop/RR_Project/Repo/"
    "RR_project/Oil Money project/CAD data/"
    "merged_with_edmonton_interpolated.csv"
)

START_DATE = "2019-01-01"
END_DATE   = "2023-12-31"

def main():
    # 1) load your existing file
    df = pd.read_csv(CSV_PATH, parse_dates=["date"])

    # 2) download USD/CAD
    usd_df = yf.download(
        "USDCAD=X",
        start=START_DATE,
        end=END_DATE,
        progress=False,
        auto_adjust=False  # ensure we get an 'Adj Close' column
    )

    # 3) pick the right price series
    if "Adj Close" in usd_df.columns:
        usd = usd_df["Adj Close"]
    else:
        usd = usd_df["Close"]

    usd.name = "usd"
    usd.index.name = "date"

    # 4) reindex onto your dates and ffill
    usd = usd.reindex(df["date"]).ffill().reset_index()

    # 5) merge in (drop any old 'usd' first just in case)
    df = df.drop(columns=["usd"], errors="ignore").merge(usd, on="date")

    # 6) overwrite the CSV
    df.to_csv(CSV_PATH, index=False)
    print(f"✅ USD/CAD updated and saved back to {CSV_PATH}")

if __name__ == "__main__":
    main()
