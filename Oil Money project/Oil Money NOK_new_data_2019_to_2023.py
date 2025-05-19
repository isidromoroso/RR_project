# coding: utf-8

# making graphs downloadable
import matplotlib
matplotlib.use('Agg')      # switch to a non-interactive backend
import matplotlib.pyplot as plt
plt.ioff()                 # turn off interactive mode

# In[1]:
# Importing libraries

import matplotlib.pyplot as plt
import statsmodels.api as sm
import pandas as pd
import numpy as np
import seaborn as sns
from sklearn.linear_model import ElasticNetCV as en 
from statsmodels.tsa.stattools import adfuller as adf

# In[2]:
# Load and preprocess the dataset

df=pd.read_csv('NOK data/brent crude nokjpy new data.csv')
df.set_index(pd.to_datetime(df[list(df.columns)[0]]),inplace=True)
del df[list(df.columns)[0]]
#df = df[df.index >= '2020-01-01']
# In[3]:
# As in the original project we define a testing period of one year
# Training period 2019-2022, Testing period 2023

# Scatter plot of NOKJPY vs Brent before 2023 (correlation plot)
ax=plt.figure(figsize=(10,5)).add_subplot(111)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.scatter(df['brent'][df.index<'2023-01-01'],df['nok'][df.index<'2023-01-01'],s=1,c='#5f0f4e')

plt.title('NOK Brent Correlation')
plt.xlabel('Brent in JPY')
plt.ylabel('NOKJPY')
plt.show()


# Dual-axis time series plot function
def dual_axis_plot(xaxis,data1,data2,fst_color='r',
                    sec_color='b',fig_size=(10,5),
                   x_label='',y_label1='',y_label2='',
                   legend1='',legend2='',grid=False,title=''):
    
    fig=plt.figure(figsize=fig_size)
    ax=fig.add_subplot(111)
    

    ax.set_xlabel(x_label)
    ax.set_ylabel(y_label1, color=fst_color)
    ax.plot(xaxis, data1, color=fst_color,label=legend1)
    ax.tick_params(axis='y',labelcolor=fst_color)
    ax.yaxis.labelpad=15

    plt.legend(loc=3)
    ax2 = ax.twinx()

    ax2.set_ylabel(y_label2, color=sec_color,rotation=270)
    ax2.plot(xaxis, data2, color=sec_color,label=legend2)
    ax2.tick_params(axis='y',labelcolor=sec_color)
    ax2.yaxis.labelpad=15

    fig.tight_layout()
    plt.legend(loc=4)
    plt.grid(grid)
    plt.title(title)
    plt.show()
    
# NOK vs Interest Rate
dual_axis_plot(df.index,df['nok'],df['interest rate'],
               fst_color='#34262b',sec_color='#cb2800',
               fig_size=(10,5),x_label='Date',
               y_label1='NOKJPY',y_label2='Norges Bank Interest Rate %',
               legend1='NOKJPY',legend2='Interest Rate',
               grid=False,title='NOK vs Interest Rate')

# NOK vs Brent Crude
dual_axis_plot(df.index,df['nok'],df['brent'],
               fst_color='#4f2d20',sec_color='#3feee6',
               fig_size=(10,5),x_label='Date',
               y_label1='NOKJPY',y_label2='Brent in JPY',
               legend1='NOKJPY',legend2='Brent',
               grid=False,title='NOK vs Brent')
               
# NOK vs Norway GDP YoY
ind=df['gdp yoy'].dropna().index
dual_axis_plot(df.loc[ind].index,
               df['nok'].loc[ind],
               df['gdp yoy'].dropna(),
               fst_color='#116466',sec_color='#ff652f',
               fig_size=(10,5),x_label='Date',
               y_label1='NOKJPY',y_label2='Norway GDP YoY %',
               legend1='NOKJPY',legend2='GDP',
               grid=False,title='NOK vs GDP')


# Linear Regression with Statsmodels
x0=pd.concat([df['usd'],df['gbp'],df['eur'],df['brent']],axis=1)
x1=sm.add_constant(x0)
x=x1[x1.index<'2023-01-01'] # Set training period
y=df['nok'][df.index<'2023-01-01'] # Set training period

model=sm.OLS(y,x).fit()
print(model.summary(),'\n')

# In[4]:

m=en(alphas=[0.0001, 0.0005, 0.001, 0.01, 0.1, 1, 10],
     l1_ratio=[.01, .1, .5, .9, .99],  max_iter=5000).fit(x0[x0.index<'2023-01-01'], y) # Set training period
print(m.intercept_,m.coef_)

print("Best l1_ratio:", m.l1_ratio_) # Print Best l1_ratio and best alpha to reproduce same parameter

print("Best alpha:", m.alpha_)

#elastic net estimation results:
#-0.6331502954082708 [-2.55348337e-02  6.19119612e-02  4.81906456e-02  7.67700858e-05]
#Best l1_ratio: 0.01
#Best alpha: 0.1

# In[5]:
# Estimate Fitted NOK 
df['sk_fit']=(df['usd']*m.coef_[0]+df['gbp']*m.coef_[1]+
                 df['eur']*m.coef_[2]+df['brent']*m.coef_[3]+m.intercept_)
# In[6]:
# Calculate Residuals
df['sk_residual']=df['nok']-df['sk_fit']

# In[7]:
# Define trading signals based on residual standard deviation bands

upper=np.std(df['sk_residual'][df.index<'2023-01-01']) 
lower=-upper

signals=pd.concat([df[i] for i in ['nok', 'usd', 'eur', 'gbp', 'brent', 'sk_fit','sk_residual']], \
                  axis=1)[df.index>='2019-01-01']
signals['fitted']=signals['sk_fit']
del signals['sk_fit']

signals['upper']=signals['fitted']+upper
signals['lower']=signals['fitted']+lower
signals['stop profit']=signals['fitted']+2*upper
signals['stop loss']=signals['fitted']+2*lower
signals['signals']=0
# In[8]:
# Signal generation logic: long/short/exit with Stop Loss and Stop Profit

index=list(signals.columns).index('signals')

for j in range(len(signals)):
    
    if signals['nok'].iloc[j]>signals['upper'].iloc[j]:
        signals.iloc[j,index]=-1  
          
    if signals['nok'].iloc[j]<signals['lower'].iloc[j]:
        signals.iloc[j,index]=1
       
    signals['cumsum']=signals['signals'].cumsum()

    if signals['cumsum'].iloc[j]>1 or signals['cumsum'].iloc[j]<-1:
        signals.iloc[j,index]=0
        signals['cumsum'] = signals['signals'].cumsum()
  
    if signals['nok'].iloc[j]>signals['stop profit'].iloc[j]:         
        signals['cumsum']=signals['signals'].cumsum()
        signals.iloc[j,index]=-signals['cumsum'].iloc[j]+1
        signals['cumsum']=signals['signals'].cumsum()
        

    if signals['nok'].iloc[j]<signals['stop loss'].iloc[j]:
        signals['cumsum']=signals['signals'].cumsum()
        signals.iloc[j,index]=-signals['cumsum'].iloc[j]-1
        signals['cumsum']=signals['signals'].cumsum()
        

signals.head(500)
# In[9]:
# Plot trading signals on NOK chart
from datetime import datetime

ax=plt.figure(figsize=(10,5)).add_subplot(111)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

signals['nok'].plot(label='NOKJPY',c='#594f4f',alpha=0.5)
ax.scatter(signals.index[signals['signals']>0],
           signals['nok'][signals['signals']>0],
           marker='^', s=100, c='#83af9b', label='LONG')
ax.scatter(signals.index[signals['signals']<0],
           signals['nok'][signals['signals']<0],
           marker='v', s=100, c='#fe4365', label='SHORT')
ax.plot(pd.to_datetime('2023-12-20'),
         signals['nok'].loc['2023-12-20'],
         lw=0,marker='*',c='#f9d423', markersize=15, alpha=0.8,
         label='Potential Exit Point of Momentum Trading')

plt.axvline(datetime.strptime('2022/07/01', '%Y/%m/%d'), linestyle=':', c='k', label='Exit')
plt.legend()
plt.title('NOKJPY Positions')
plt.ylabel('NOKJPY')
plt.xlabel('Date')
plt.show()


# In[10]:
# Plot actual vs fitted with confidence bands

ax=plt.figure(figsize=(10,5)).add_subplot(111)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

signals['fitted'].plot(lw=2.5,label='Fitted',c='w',alpha=0.6)
signals['nok'].plot(lw=2,label='Actual',c='#04060f',alpha=0.8)
ax.fill_between(signals.index,signals['upper'],
                signals['lower'],alpha=0.2,label='1 Sigma',color='#2a3457')
ax.fill_between(signals.index,signals['stop profit'],
                signals['stop loss'],alpha=0.1,label='2 Sigma',color='#720017')

plt.legend(loc='best')
plt.title('Fitted vs Actual')
plt.ylabel('NOKJPY')
plt.xlabel('Date')
plt.show()


# In[11]:


# In[12]:
# Plot normalized price trends (for visual comparison)

ax=plt.figure(figsize=(10,5)).add_subplot(111)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

(df['nok']/df['nok'][0]*100).plot(c='#ff8c94',label='Norwegian Krone',alpha=0.9)
(df['usd']/df['usd'][0]*100).plot(c='#9de0ad',label='US Dollar',alpha=0.9)
(df['eur']/df['eur'][0]*100).plot(c='#45ada8',label='Euro',alpha=0.9)
(df['gbp']/df['gbp'][0]*100).plot(c='#f8b195',label='UK Sterling',alpha=0.9)
(df['brent']/df['brent'][0]*100).plot(c='#6c5b7c',label='Brent Crude',alpha=0.5)

plt.legend(loc='best')
plt.ylabel('Normalized Price by 100')
plt.xlabel('Date')
plt.title('Trend')
plt.show()


# In[13]:
# Stationarity test on residuals using ADF (Augmented Dickey-Fuller)

x2=df['eur'][df.index<'2023-01-01']
x3=sm.add_constant(x2)

model=sm.OLS(y,x3).fit()
ero=model.resid

print(adf(ero)) # Test for stationarity
print(model.summary())

# In[14]:
# Simulate trading strategy: backtest PnL

capital0=2000
positions=100
portfolio=pd.DataFrame(index=signals.index)
portfolio['holding']=signals['nok']*signals['cumsum']*positions
portfolio['cash']=capital0-(signals['nok']*signals['signals']*positions).cumsum()
portfolio['total asset']=portfolio['holding']+portfolio['cash']
portfolio['signals']=signals['signals']


# In[15]:
# Trim portfolio for date range

start_date = '2018-12-31'
end_date = '2023-12-31'

portfolio=portfolio[portfolio.index>start_date]
portfolio=portfolio[portfolio.index<end_date]


# In[16]:
# Plot portfolio performance and signal points

ax=plt.figure(figsize=(10,5)).add_subplot(111)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

portfolio['total asset'].plot(c='#594f4f',alpha=0.5,label='Total Asset')
ax.scatter(portfolio.loc[portfolio['signals']>0].index,
           portfolio['total asset'][portfolio['signals']>0],
           marker='^', c='#2a3457', label='LONG', s=100, alpha=0.5)  
ax.scatter(portfolio.loc[portfolio['signals']<0].index,
           portfolio['total asset'][portfolio['signals']<0],
           marker='v', c='#720017', label='The Big Short', s=150, alpha=0.5)
plt.legend()
plt.title('Portfolio Performance')
plt.ylabel('Asset Value')
plt.xlabel('Date')
plt.show()


# Calculate return % of the strategy
initial_value = portfolio['total asset'].iloc[0]
final_value = portfolio['total asset'].iloc[-1]
portfolio_return_pct = ((final_value - initial_value) / initial_value) * 100

# Print return
print(f"Portfolio return from {start_date} to {end_date}: {portfolio_return_pct:.2f}%")

# This strategy works much better for the new data
# The main reason is the better forecast of NOK
# Bullish trend after COVID crash can be another reason
# If we consider just the results after the crash the results are even better
# One possible improve could be avoid trading during high volatility periods

#In[17]:
# Oil_money_trading_backtest improved trading strategy optimised
# Import trading backtest strategy

import oil_money_trading_backtest_new_data_2019_to_2023 as om

dataset = df # I use df because I want to check the results for the whole period
dataset.reset_index(inplace=True)

signals=om.signal_generation(dataset,'brent','nok',om.oil_money)
p=om.portfolio(signals,'nok')
om.plot(signals,'nok')
om.profit(p,'nok')

dic={}
for holdingt in range(5,20):
    for stopp in np.arange(0.3,1.1,0.05):
        signals=om.signal_generation(dataset,'brent','nok',om.oil_money,
                                     holding_threshold=holdingt,
                                    stop=stopp)
        
        p=om.portfolio(signals,'nok')
        dic[holdingt,stopp]=p['asset'].iloc[-1]/p['asset'].iloc[0]-1
     
profile=pd.DataFrame({'params':list(dic.keys()),'return':list(dic.values())})


# In[18]:
# Plot histogram with the distribution of the return

ax=plt.figure(figsize=(10,5)).add_subplot(111)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
profile['return'].apply(lambda x:x*100).hist(histtype='bar', \
                                            color='#f09e8c', \
                                            width=0.45,bins=20)
plt.title('Distribution of Return on NOK Trading')
plt.grid(False)
plt.ylabel('Frequency')
plt.xlabel('Return (%)')
plt.show()

# With this new data the imported trading strategy doesn't work well
# giving a distribution of return between -16% and 6%


# In[19]:
# Plot heatmap of return under different parameters

matrix=pd.DataFrame(columns= \
                    [round(i,2) for i in np.arange(0.3,1.1,0.05)])

matrix['index']=np.arange(5,20)
matrix.set_index('index',inplace=True)

for i,j in profile['params']:
    matrix.at[i,round(j,2)]= \
    profile['return'][profile['params']==(i,j)].item()*100

for i in matrix.columns:
    matrix[i]=matrix[i].apply(float)


fig=plt.figure(figsize=(10,5))
ax=fig.add_subplot(111)
sns.heatmap(matrix,cmap='gist_heat_r',square=True, \
            xticklabels=3,yticklabels=3)
ax.collections[0].colorbar.set_label('Return(%) \n', \
                                     rotation=270)
plt.xlabel('\nStop Loss/Profit (points)')
plt.ylabel('Position Holding Period (days)\n')
plt.title('Profit Heatmap\n',fontsize=10)
plt.style.use('default')

# Once again terrible returns under almost every condition
# Only positive results with a small Stop Loss/Profit and holding period of 14-16 days
# We can observe clearly how this strategy has been optimised for other period
# The market condtions have changed a lot during this 10 years (2013 to 2023)

#In[20]
#downloading all outputted figures in the file
import os

base_dir   = 'NOK Data/'
out_folder = os.path.join(base_dir, 'py_graphs_new_data')
os.makedirs(out_folder, exist_ok=True)

for idx, num in enumerate(plt.get_fignums(), start=1):
    fig = plt.figure(num)
    fig.savefig(
        os.path.join(out_folder, f'figure_{idx}.png'),
        dpi=300, bbox_inches='tight'
    )
plt.close('all')
# %%
