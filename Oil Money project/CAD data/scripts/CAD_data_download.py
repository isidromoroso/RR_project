#!/usr/bin/env python3
# CAD_data_download.py
# Fetch Western Canadian Select (WCS) weekly spot prices from EIA v1,
# expand to business‐day frequency and save as CSV in M/D/YYYY format.

import requests
import pandas as pd

API_KEY = '5SDhKlXzmsxaqtuNnPEpPYAQLr3AiMpU3JRySXXP'
START_DATE = '2019-01-01'
END_DATE   = '2023-12-31'

def fetch_wcs(api_key):
    """Fetch the WCS weekly series via EIA v1 /series endpoint."""
    url = 'https://api.eia.gov/series/'
    params = {
        'api_key': api_key,
        'series_id': 'PET.RWCS.HARDISTY.W'   # WCS weekly at Hardisty
    }
    resp = requests.get(url, params=params)
    resp.raise_for_status()
    js = resp.json()
    if 'series' not in js or not js['series']:
        raise RuntimeError("No WCS data returned—check your API key or series ID")
    raw = js['series'][0]['data']  # list of [date_str, value]
    df = pd.DataFrame(raw, columns=['date','wcs'])
    df['date'] = pd.to_datetime(df['date'])  # ISO dates like '2020-01-06'
    return df

def expand_to_business_days(df, start, end):
    """Reindex to business days, forward‐fill last known weekly price."""
    idx = pd.date_range(start, end, freq='B')
    expanded = (df.set_index('date')
                  .reindex(idx)      # introduce all business days
                  .ffill()           # carry last weekly price forward
                  .rename_axis('date')
                  .reset_index())
    return expanded

def main():
    wcs_weekly = fetch_wcs(API_KEY)
    wcs_daily  = expand_to_business_days(wcs_weekly, START_DATE, END_DATE)
    wcs_daily['date'] = wcs_daily['date'].dt.strftime('%-m/%-d/%Y')
    wcs_daily.to_csv('WCS_daily_2019-2023.csv', index=False)
    print("WCS data (2019–2023) saved to WCS_daily_2019-2023.csv")

if __name__ == '__main__':
    main()
