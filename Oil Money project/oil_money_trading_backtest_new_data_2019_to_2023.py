
# coding: utf-8

# In[1]:
# Import libraries

import statsmodels.api as sm
import copy
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt


# In[2]:
# Oil Money function

def oil_money(dataset):
    
    df=copy.deepcopy(dataset)
    
    df['signals']=0
    df['pos2 sigma']=0.0
    df['neg2 sigma']=0.0
    df['pos1 sigma']=0.0
    df['neg1 sigma']=0.0
    df['forecast']=0.0
    
    return df


# In[3]:
# Signal generation function

def signal_generation(dataset,x,y,method, \
                      holding_threshold=10, \
                      stop=0.5,rsquared_threshold=0.7, \
                      train_len=50):
    
    df=method(dataset)
    holding=0
    trained=False
    counter=0

    for i in range(train_len,len(df)):
        
        if holding!=0:
            
            if counter>holding_threshold:
                df.at[i,'signals']=-holding            
                holding=0
                trained=False
                counter=0
                continue

            if np.abs( \
                      df[y].iloc[i]-df[y][df['signals']!=0].iloc[-1] \
                      )>=stop:
                df.at[i,'signals']=-holding        
                holding=0
                trained=False
                counter=0
            
                continue
        
            counter+=1
    
        else:

            if not trained:
                X=sm.add_constant(df[x].iloc[i-train_len:i])
                Y=df[y].iloc[i-train_len:i]
                m=sm.OLS(Y,X).fit()
                if m.rsquared>rsquared_threshold:
                    trained=True
                    sigma=np.std(Y-m.predict(X))

                    df.loc[i:,'forecast']= \
                    m.predict(sm.add_constant(df[x].iloc[i:]))
                    
                    df.loc[i:,'pos2 sigma']= \
                    df['forecast'].iloc[i:]+2*sigma
                    
                    df.loc[i:,'neg2 sigma']= \
                    df['forecast'].iloc[i:]-2*sigma
                    
                    df.loc[i:,'pos1 sigma']= \
                    df['forecast'].iloc[i:]+sigma
                    
                    df.loc[i:,'neg1 sigma']= \
                    df['forecast'].iloc[i:]-sigma

            if trained:
                if df[y].iloc[i]>df['pos2 sigma'].iloc[i]:
                    df.at[i,'signals']=1
                    holding=1

                    df.at[i:,'pos2 sigma']=df['forecast']
                    df.at[i:,'neg2 sigma']=df['forecast']
                    df.at[i:,'pos1 sigma']=df['forecast']
                    df.at[i:,'neg1 sigma']=df['forecast']
                    
                if df[y].iloc[i]<df['neg2 sigma'].iloc[i]:
                    df.at[i,'signals']=-1
                    holding=-1
                    
                    df.at[i:,'pos2 sigma']=df['forecast']
                    df.at[i:,'neg2 sigma']=df['forecast']
                    df.at[i:,'pos1 sigma']=df['forecast']
                    df.at[i:,'neg1 sigma']=df['forecast']

                    
    return df
    


# In[4]:
# Portfolio function

def portfolio(signals,close_price,capital0=5000):   
    
    positions=capital0//max(signals[close_price])
    portfolio=pd.DataFrame()
    portfolio['close']=signals[close_price]
    portfolio['signals']=signals['signals']
    
    portfolio['holding']=portfolio['signals'].cumsum()* \
    portfolio['close']*positions

    portfolio['cash']=capital0-(portfolio['signals']* \
                                portfolio['close']*positions).cumsum()
   
    portfolio['asset']=portfolio['holding']+portfolio['cash']
    

    return portfolio


# In[5]:
# Plot function

def plot(signals,close_price):
    
    data=copy.deepcopy(signals[signals['forecast']!=0])
    ax=plt.figure(figsize=(10,5)).add_subplot(111)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    
    data['forecast'].plot(label='Fitted',color='#f4f4f8',alpha=0.7)
    data[close_price].plot(label='Actual',color='#3c2f2f',alpha=0.7)
    
    ax.fill_between(data.index,data['pos1 sigma'], \
                    data['neg1 sigma'],alpha=0.3, \
                    color='#011f4b', label='1 Sigma')
    ax.fill_between(data.index,data['pos2 sigma'], \
                    data['neg2 sigma'],alpha=0.3, \
                    color='#ffc425', label='2 Sigma')
    
    ax.scatter(data.loc[data['signals'] == 1].index,
            data[close_price][data['signals'] == 1],
            marker='^', c='#00b159', label='LONG', s=121, alpha=1)

    ax.scatter(data.loc[data['signals'] == -1].index,
            data[close_price][data['signals'] == -1],
            marker='v', c='#ff6f69', label='SHORT', s=121, alpha=1)
    
    plt.title(f'Oil Money Project\n{close_price.upper()} Positions')
    plt.legend(loc='best')
    plt.xlabel('Date')
    plt.ylabel('Price')
    plt.show()


# In[6]:
# Profit function

def profit(portfolio,close_price):
    
    data=copy.deepcopy(portfolio)
    ax=plt.figure(figsize=(10,5)).add_subplot(111)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    
    data['asset'].plot(label='Total Asset',color='#58668b')

    ax.scatter(data.index[data['signals']>0],
           data['asset'][data['signals']>0],
           marker='^', s=100, c='#00b159', label='LONG')
    ax.scatter(data.index[data['signals']<0],
           data['asset'][data['signals']<0],
           marker='v', s=100, c='#ff6f69', label='SHORT')
    
    plt.title(f'Oil Money Project\n{close_price.upper()} Total Asset')
    plt.legend(loc='best')
    plt.xlabel('Date')
    plt.ylabel('Asset Value')
    plt.show()


# In[7]:
# Main function
# Strategy testing

def main():
    
    df = pd.read_csv('NOK data/brent crude nokjpy new data.csv')
    df.columns = df.columns.str.replace('\ufeff', '')
    signals=signal_generation(df,'brent','nok',oil_money)
    p=portfolio(signals,'nok')
    
    signals.set_index('date',inplace=True)
    signals.index=pd.to_datetime(signals.index,format='%m/%d/%Y')
    p.set_index(signals.index,inplace=True)
    
    # Set rows 250 to 800 (arbitrary sample decision)
    plot(signals.iloc[250:800],'nok')
    profit(p.iloc[250:800],'nok')

    date_range = signals.iloc[250:600].index

    print("Date range for rows 250 to 800:")
    print(f"From: {date_range[0].date()} To: {date_range[-1].date()}")

if __name__ == '__main__':
    main()

# %%