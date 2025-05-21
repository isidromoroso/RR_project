#!/usr/bin/env python3
import os
import requests
import pandas as pd

# where to save
out_dir = (
    "/Users/jackshephard-thorn/Desktop/RR_Project/Repo/"
    "RR_project/Oil Money project/CAD data/Edmonton Data"
)
os.makedirs(out_dir, exist_ok=True)

months = [
    "january","february","march","april","may","june",
    "july","august","september","october","november","december"
]
years = range(2019, 2024)  # 2019-2023
base = "https://natural-resources.canada.ca/energy-sources/fossil-fuels"

for year in years:
    for i, m in enumerate(months, start=1):
        # try multiple URL patterns (with/without year, singular/plural)
        paths = [
            f"selected-crude-oil-price-daily-{m}-{year}-canadian-dollars-cubic-metre",
            f"selected-crude-oil-price-daily-{m}-canadian-dollars-cubic-metre",
            f"selected-crude-oil-prices-{m}-{year}-canadian-dollars-cubic-metre",
            f"selected-crude-oil-prices-{m}-canadian-dollars-cubic-metre",
            f"selected-daily-crude-oil-prices-{m}-{year}-canadian-dollars-cubic-metre",
            f"selected-daily-crude-oil-prices-{m}-canadian-dollars-cubic-metre"
        ]
        resp = None
        for p in paths:
            url = f"{base}/{p}"
            try:
                r = requests.get(url, timeout=10)
                if r.status_code == 200:
                    resp = r
                    break
            except requests.RequestException:
                continue
        if resp is None:
            print(f"⚠️  {m.title()} {year}: NOT FOUND under any variant")
            continue
        # parse the first HTML table
        try:
            df = pd.read_html(resp.text)[0]
        except ValueError:
            print(f"⚠️  {m.title()} {year}: no table found")
            continue
        # normalize headers
        df.columns = [c.strip() for c in df.columns]
        # parse date column
        date_col = next((c for c in df.columns if 'date' in c.lower()), None)
        if date_col:
            df[date_col] = pd.to_datetime(df[date_col], errors='coerce')
        # rename price column to Edmonton
        price_col = next((c for c in df.columns if 'edmonton' in c.lower()), None)
        if not price_col:
            price_col = next((c for c in df.select_dtypes('number').columns), None)
        if price_col:
            df = df.rename(columns={price_col: 'Edmonton_Price'})
        # save CSV
        fn = os.path.join(out_dir, f"nrcan-{year}-{i:02d}.csv")
        df.to_csv(fn, index=False)
        print(f"→ Saved {fn} ({len(df)} rows)")
