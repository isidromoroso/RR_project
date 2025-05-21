#!/usr/bin/env python3
"""
Merges your existing daily CSV (cadaud_from_yahoo.csv) with monthly WCS JSON,
interpolates to daily (business-day), places date first, then wcs, then all
your original columns in their original order, and writes out a new CSV.
"""
import os
import json
import pandas as pd

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))

    # 1) Load your original daily CSV (with its original column names)
    daily_csv = os.path.join(base_dir, 'cadaud_from_yahoo.csv')
    if not os.path.isfile(daily_csv):
        raise FileNotFoundError(f"Daily CSV not found: {daily_csv}")
    df_daily = pd.read_csv(daily_csv, parse_dates=['date'])

    # 2) Load the monthly WCS JSON
    monthly_json = os.path.join(base_dir, 'wcs_monthly.json')
    if not os.path.isfile(monthly_json):
        raise FileNotFoundError(f"Monthly JSON not found: {monthly_json}")
    with open(monthly_json, 'r') as f:
        raw = json.load(f)

    # 3) Build the monthly DataFrame and filter for WCS only
    df_monthly = pd.DataFrame(raw)
    df_monthly = df_monthly[df_monthly['Type '] == 'WCS']
    df_monthly['date'] = pd.to_datetime(df_monthly['Date'])
    df_monthly = df_monthly[['date', 'Value']].rename(columns={'Value': 'wcs_monthly'})

    # 4) Merge on date (keeps all rows of your original daily CSV)
    df = pd.merge(df_daily, df_monthly, on='date', how='left')

    # 5) Interpolate wcs both forward and backward to fill all business days
    df['wcs'] = df['wcs_monthly'].interpolate(method='linear', limit_direction='both')
    df = df.drop(columns=['wcs_monthly'])

    # 6) Reorder columns: date first, then wcs, then exactly the rest in their original order
    original_cols = [c for c in df_daily.columns if c != 'date']
    df = df[['date', 'wcs'] + original_cols]

    # 7) Save the result next to the script
    out_file = os.path.join(base_dir, 'daily_with_interpolated_wcs.csv')
    df.to_csv(out_file, index=False)
    print(f"✅ Saved merged and interpolated CSV to: {out_file}")

if __name__ == '__main__':
    main()
