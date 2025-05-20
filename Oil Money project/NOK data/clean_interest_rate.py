import pandas as pd

# Load original interest rate data (semicolon-separated)
raw_df = pd.read_csv("norway_interest_rate.csv", sep=";") # Source Norges Bank: https://app.norges-bank.no/query/#/en/interest?interesttype=KPRA&unitofmeasure=R&duration=SD&frequency=B&startdate=2019-01-01&stopdate=2023-12-31

# Keep only date and value
clean_df = raw_df[['TIME_PERIOD', 'OBS_VALUE']].copy()
clean_df.columns = ['date', 'interest rate']

# Convert date column to datetime
clean_df['date'] = pd.to_datetime(clean_df['date'])

# Save cleaned version
clean_df.to_csv("norway_interest_rate_cleaned.csv", index=False)
print("Cleaned interest rate data saved to 'norway_interest_rate_cleaned.csv'")
