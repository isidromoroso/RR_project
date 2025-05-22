import pandas as pd

# 1) Load your merged file
df = pd.read_csv(
    'CAD data/merged_with_edmonton.csv',
    parse_dates=['date']
)

# 2) Make sure it's sorted and indexed by date
df = df.sort_values('date').set_index('date')

# 3) Replace any infinities (just in case) and then interpolate
df['edmonton'] = df['edmonton'].replace([float('inf'), -float('inf')], pd.NA)
# time-based linear interpolation:
df['edmonton'] = df['edmonton'].interpolate(method='time')

# 4) (Optional) forward/backward fill any remaining NaNs at the very ends
df['edmonton'] = df['edmonton'].ffill().bfill()

# 5) Write it back out
df.reset_index().to_csv(
    '/Users/jackshephard-thorn/Desktop/RR_Project/Repo/RR_project/Oil Money project/CAD data/merged_with_edmonton_interpolated.csv',
    index=False
)
