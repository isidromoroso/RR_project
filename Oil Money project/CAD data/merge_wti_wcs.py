#!/usr/bin/env python3

import json
import pandas as pd
from pandas_datareader.data import DataReader

def main():
    start, end = '2019-01-01', '2023-12-31'

    # 1) Fetch daily WTI from FRED
    wti = DataReader('DCOILWTICO', 'fred', start, end)
    wti = wti.rename(columns={'DCOILWTICO':'wti'}).reset_index()
    # rename the first column (DATE or index) to 'date'
    first_col = wti.columns[0]
    wti = wti.rename(columns={first_col: 'date'})
    wti['date'] = pd.to_datetime(wti['date'])

    # 2) Load monthly WCS from local JSON
    with open('wcs.json', 'r') as f:
        wcs_raw = json.load(f)['series'][0]['data']
    wcs = pd.DataFrame(wcs_raw, columns=['date','wcs'])
    wcs['date'] = pd.to_datetime(wcs['date'])

    # 3) Forward-fill WCS to business days
    biz_days = pd.date_range(start, end, freq='B')
    wcs = (
        wcs
        .set_index('date')
        .reindex(biz_days)
        .ffill()
        .rename_axis('date')
        .reset_index()
    )

    # 4) Merge and sort
    df = wti.merge(wcs, on='date', how='inner').sort_values('date')

    # 5) Format and export
    df['date'] = df['date'].dt.strftime('%-m/%-d/%Y')
    df.to_csv('WTI WCS cadaud.csv', index=False)
    print("✅ WTI WCS cadaud.csv created!")

if __name__ == '__main__':
    main()
