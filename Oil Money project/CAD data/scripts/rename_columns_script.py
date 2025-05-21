#!/usr/bin/env python3
"""
Rename columns of daily_with_interpolated_wcs.csv to match wcs crude cadaud.csv
(original column order is preserved).
"""
import os
import pandas as pd

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))

    # Paths
    new_csv = os.path.join(base_dir, 'daily_with_interpolated_wcs.csv')
    if not os.path.isfile(new_csv):
        raise FileNotFoundError(f"File not found: {new_csv}")

    # Read it in
    df = pd.read_csv(new_csv, parse_dates=['date'])

    # Rename mapping: current → original
    rename_map = {
        'CL=F': 'wti',
        'NG=F': 'gas',
        'GC=F': 'gold',
        'CADUSD=X': 'cad',
        'AUDUSD=X': 'aud',
        'EURUSD=X': 'eur',
        'CNYUSD=X': 'cny',
        'MXNUSD=X': 'mxn',
        'JPYUSD=X': 'jpy',
        'GBPUSD=X': 'gbp',
        'KRWUSD=X': 'krw',
        # 'date' and 'wcs' already match
    }

    df = df.rename(columns=rename_map)

    # Verify the final column order matches the original
    # (you can manually adjust this list if needed)
    final_cols = ['date', 'wcs'] + [rename_map.get(col, col) for col in df.columns if col not in ('date','wcs')]
    df = df[final_cols]

    # Save back
    df.to_csv(new_csv, index=False)
    print(f"✅ Renamed columns and saved to: {new_csv}")

if __name__ == '__main__':
    main()
