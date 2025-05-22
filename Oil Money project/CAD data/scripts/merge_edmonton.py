#!/usr/bin/env python3
import os
import pandas as pd
from glob import glob

# ─── CONFIG ─────────────────────────────────────────────────────────────────────
DATA_DIR = (
    "CAD data/Edmonton Data"
)
OUT_FILE = os.path.join(DATA_DIR, "nrcan-edmonton-wcs-daily.csv")
# ────────────────────────────────────────────────────────────────────────────────

def main():
    pattern = os.path.join(DATA_DIR, "nrcan-*.csv")
    files = sorted(glob(pattern))
    if not files:
        print("No files found matching", pattern)
        return

    dfs = []
    for fn in files:
        df = pd.read_csv(fn)
        # strip whitespace
        df.columns = [c.strip() for c in df.columns]

        # find date column
        date_cols = [c for c in df.columns if "date" in c.lower()]
        if not date_cols:
            print(f" ⚠️ skipping {os.path.basename(fn)} – no date column")
            continue
        date_col = date_cols[0]
        df[date_col] = pd.to_datetime(df[date_col], errors="coerce")

        # pick price column: among other cols, try to_numeric and count valid
        best_col, best_count = None, 0
        for c in df.columns:
            if c == date_col:
                continue
            # try convert
            num = pd.to_numeric(df[c], errors="coerce")
            cnt = num.notna().sum()
            if cnt > best_count:
                best_count, best_col = cnt, c

        if best_col is None or best_count == 0:
            print(f" ⚠️ skipping {os.path.basename(fn)} – no numeric column")
            continue

        # take only date + that numeric column
        dfn = pd.DataFrame({
            "date": df[date_col],
            "WCS_CAD_per_m3": pd.to_numeric(df[best_col], errors="coerce")
        }).dropna(subset=["date"])

        dfs.append(dfn)

    if not dfs:
        print("No dataframes to concatenate, aborting.")
        return

    # concat, dedupe, sort
    all_df = pd.concat(dfs, ignore_index=True)
    all_df = (all_df
              .drop_duplicates(subset=["date"])
              .sort_values("date")
              .reset_index(drop=True))
    all_df["date"] = all_df["date"].dt.strftime("%Y-%m-%d")

    # write out
    all_df.to_csv(OUT_FILE, index=False)
    print(f"✔️  Merged {len(dfs)} files → {OUT_FILE} ({len(all_df)} rows)")

if __name__ == "__main__":
    main()
