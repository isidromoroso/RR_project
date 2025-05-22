# Oil Money Reproducible Research Project

## Table of Contents

- [Introduction](#introduction)
- [Original “Oil Money” Study](#original-oil-money-study)
- [What did in this Project](#what-did-in-this-project)
- [Repository Structure](#repository-structure)

## Introduction  
This repository holds our reproducible-research project for the “Reproducible Research” course. We build on the existing **Oil Money** analysis by Je-suis-tm to:

1. **Reproduce** all original Python notebooks and confirm each output locally.  
2. **Port** the entire workflow into R, validating that the R scripts yield numerically and visualy equivalent results.  
3. **Extend** the analysis to cover **January 2019 through December 2023**, testing whether the petrocurrency trading signals persist.

---

## Original “Oil Money” Study  

The **Oil Money** project explores whether currencies of oil-exporting countries (“petrocurrencies”) move predictably with their local crude benchmarks in a way that can be traded.  

- **Hypothesis**  
  Oil-price shocks drive FX rates beyond mere correlation, offering exploitable predictive power.  

- **Data & Benchmarks**  
  - FX vs. USD for NOK, RUB, CAD, COP  
  - Oil benchmarks: Brent, Urals, WCS, Vasconia  

- **Modeling Approach**  
  1. Rolling-window regressions of FX on its oil price and the USD index.  
  2. Elastic-net regularization (α, λ tuned by cross-validation).  
  3. Signal generation: enter when FX deviates ±1 σ from its model forecast.  
  4. Exit rules: mean-reversion (zero deviation) or momentum (±2 σ).  
  5. Backtest P&L, Sharpe ratio, drawdown.  

- **Key Findings**  
  - **NOK/Brent**: Robust link; momentum trades profitable.  
  - **RUB/Urals**: Geopolitical shocks dominate; no consistent signals.  
  - **CAD/WCS**: USD effects overshadow direct oil–FX causality.  
  - **COP/Vasconia**: Clear pre-2017 patterns; mixed afterward, but momentum still works.  

---

## What did in this Project  
Building on the original work, our team of three will:

1. **Reproduce the Original Python Analysis**  
   - Clone the **Oil Money** repo and install dependencies.  
   - Execute all Python notebooks locally, confirm that each figure, table, and regression output matches the author’s results.
   - **Scope**: Only three “petrocurrencies”—  
     - **Norwegian Krone (NOK)** vs. Brent  
     - **Canadian Dollar (CAD)** vs. Western Canadian Select (WCS)  
     - **Colombian Peso (COP)** vs. Vasconia  
  	 - We will _exclude_ Russian Ruble (RUB) due to political regimes and sanctions, and the Russian oil story no longer fitting the simple strategy.  

2. **Port the Analysis to R**  
   - Rewrite data‐import, cleaning, modelling, and plotting in R (tidyverse, `lm`, `glmnet`, etc.).  
   - Verify that the R scripts produce numerically and visualy equivalent results to the Python versions.

3. **Extend to New Data: 2019–2023**  
   - **Data Sources**:  
     - Exchange rates and major currencies: We fetched daily FX rates for each petrocurrency and related currencies, quoting each pair against a low-correlated benchmark (e.g., JPY, AUD) to isolate oil-driven movements from Yahoo finance library (yfinance).  
     - Oil benchmarks: Brent (yfinance), WCS and Vasconia.
	 - Interest rates: Norway (Norges Bank)
	 - GDP yoy growth: Norway (FRED) 

4. **Compare and Interpret**  
   - Assess whether the original regression fits (R², t-stats, elastic-net selections) hold in 2019–2023.  
   - Re‐generate trading signals (mean-reversion and momentum) and backtest P&L.  
   - Visualize changes: We observed how the market coditions changes making some strategies to work better and some worse during this more recent period


---

## Repository Structure

All files and folders live directly under the **Oil Money project** root:

### Folders  
- **CAD data/**  
  Python files used to generate 2019 to 2023 data, .csv new data files and three folder with the graphs from the original python file, the translated R file and the python file with the new data 
- **COP Data/**  
  Same structure for the Colombian-peso analysis.  
- **NOK data/**  
  Same structure for the Norwegian-krone analysis.  
- **Presentation/**  
  A Quarto (`.qmd`) summary comparing original vs. extended-data plots with narrative.  
- **data/**  
  Raw CSV time-series (FX rates and oil prices) from the original Oil Money repo (2010–2019).  
- **oil production/**  
  Author’s oil-production datasets used in auxiliary checks.  
- **preview/**  
  Static copies of the original author’s published charts and figures.  
- **__pycache__/**, **.RData**  
  Auto-generated caches and saved R workspaces. 
### Scripts & Files  
- **README.md** — this file.  
- **Oil Money CAD.py** / **Oil Money CAD_new_data_2019_to_2023.py**  
- **CAD_local_.R** / **Oil_Money_CAD_analysis.R**  
- **Oil Money COP.py** / **COP_locally_.R**  
- **Oil Money NOK.py** / **Oil Money NOK.r** / **Oil Money NOK_new_data_2019_to_2023.py**  
- **Oil Money RUB.py**  
- **oil_money_trading_backtest.py** / **oil_money_trading_backtest_new_data_2019_to_2023.py** / **oil_money_trading_backtest.R**  

  Each currency script pair follows the pattern:  
  1. Reproduce the original Python analysis (`*.py`).  
  2. Port to R (`*.R` or `_locally_.R`).  
  3. Fetch and analyze new data (`*_new_data_2019_to_2023.py`).

---