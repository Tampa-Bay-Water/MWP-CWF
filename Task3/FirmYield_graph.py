import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.transforms import Bbox
import seaborn as sns
from statsmodels.graphics.tsaplots import plot_acf, plot_pacf
import LoadData

FIG_TITLE_FONTSIZE = 16
TITLE_FONTSIZE = 14
AX_LABEL_FONTSIZE = 12

D_PROJECT = os.path.dirname(__file__)


def plot_wf_pumpage_ts(df,int_stats):
    wfname = df.Wellfield.values[0]

    fig, axes = plt.subplots(3, 1, figsize=(13, 16))

    df = df.drop('Wellfield', axis=1)
    sns.lineplot(ax=axes[0], x='Date', y='WF_Pumpage', data=df)
    df['lower'] = df['WF_Pumpage']-0.5*df['StdPumpage']
    df['upper'] = df['WF_Pumpage']+0.5*df['StdPumpage']
    axes[0].fill_between(df['Date'], df['lower'], df['upper'], color='lightblue', alpha=0.75
        , label='Point Stdev')

    axes[0].set_xlabel("Date", fontsize=AX_LABEL_FONTSIZE)
    axes[0].set_ylabel(int_stats, fontsize=AX_LABEL_FONTSIZE)
    axes[0].set_title(f'{int_stats} - {wfname}', fontsize=TITLE_FONTSIZE)

    mean_value = df['WF_Pumpage'].mean()
    stdev_value = df['WF_Pumpage'].std()
    yreg = [mean_value-stdev_value*0.5, mean_value+stdev_value*0.5]
    axes[0].axhspan(yreg[0], yreg[1], color='grey', alpha=0.3)
    ylim = axes[0].get_ylim()
    axes[0].set_ylim([0,ylim[1]])

    # Plot ACF in the middle subplot
    plot_acf(df['WF_Pumpage'], lags= 60, ax=axes[1], title='Autocorrelation Function (ACF)')

    # Plot PACF in the bottom subplot
    plot_pacf(df['WF_Pumpage'], lags= 60, ax=axes[2], title='Partial Autocorrelation Function (PACF)', method='ywm')

    plt.tight_layout()

    svfilePath = os.path.join(D_PROJECT,'plotWarehouse',f'{int_stats}_{wfname}')
    fig.savefig(svfilePath, facecolor='auto', edgecolor='auto', bbox_inches='tight')
    fig.savefig(svfilePath+'.pdf', facecolor='auto', edgecolor='auto', orientation="portrait"
        , bbox_inches='tight')

    plt.show(block=False)
    fig.clf()
    plt.close()
    return

def plot_wf_pumpage_ts1(df,int_stats):
    wfname = [df[0].Wellfield.values[0],df[1].Wellfield.values[0]]

    fig, axes = plt.subplots(2, 1, figsize=(13, 16))

    # df[0]['lower'] = df[0]['WF_Pumpage']-df[0][]
    df[0] = df[0].drop('Wellfield', axis=1)
    sns.lineplot(ax=axes[0], x='Date', y='WF_Pumpage', data=df[0], color='blue')
    df[0]['lower'] = df[0]['WF_Pumpage']-0.5*df[0]['StdPumpage']
    df[0]['upper'] = df[0]['WF_Pumpage']+0.5*df[0]['StdPumpage']
    axes[0].fill_between(df[0]['Date'], df[0]['lower'], df[0]['upper'], color='lightblue', alpha=0.75
        , label='Point Stdev')

    axes[0].set_xlabel("Date", fontsize=AX_LABEL_FONTSIZE)
    axes[0].set_ylabel('Pumpage, mgd', fontsize=AX_LABEL_FONTSIZE)
    axes[0].set_title(f'{int_stats} - {wfname[0]}', fontsize=TITLE_FONTSIZE)

    mean_value = df[0]['WF_Pumpage'].mean()
    stdev_value = df[0]['WF_Pumpage'].std()
    yreg = [mean_value-stdev_value*0.5, mean_value+stdev_value*0.5]
    axes[0].axhspan(yreg[0], yreg[1], color='grey', alpha=0.3)
    ylim = axes[0].get_ylim()
    axes[0].set_ylim([0,ylim[1]])

    df[1] = df[1].drop('Wellfield', axis=1)
    sns.lineplot(ax=axes[1], x='Date', y='WF_Pumpage', data=df[1])
    df[1]['lower'] = df[1]['WF_Pumpage']-0.5*df[1]['StdPumpage']
    df[1]['upper'] = df[1]['WF_Pumpage']+0.5*df[1]['StdPumpage']
    axes[1].fill_between(df[1]['Date'], df[1]['lower'], df[1]['upper'], color='lightblue', alpha=0.75
        , label='Point Stdev')

    axes[1].set_xlabel("Date", fontsize=AX_LABEL_FONTSIZE)
    axes[1].set_ylabel(int_stats, fontsize=AX_LABEL_FONTSIZE)
    axes[1].set_title(f'{int_stats} - {wfname[1]}', fontsize=TITLE_FONTSIZE)

    mean_value = df[1]['WF_Pumpage'].mean()
    stdev_value = df[1]['WF_Pumpage'].std()
    yreg = [mean_value-stdev_value*0.5, mean_value+stdev_value*0.5]
    axes[1].axhspan(yreg[0], yreg[1], color='grey', alpha=0.3)
    ylim = axes[1].get_ylim()
    axes[1].set_ylim([0,ylim[1]])

    plt.tight_layout()

    svfilePath = os.path.join(D_PROJECT,'plotWarehouse',f'{int_stats}_{wfname[0]}-{wfname[1]}')
    fig.savefig(svfilePath, facecolor='auto', edgecolor='auto', bbox_inches='tight')
    fig.savefig(svfilePath+'.pdf', facecolor='auto', edgecolor='auto', orientation="portrait"
        , bbox_inches='tight')

    plt.show(block=False)
    fig.clf()
    plt.close()
    return

def plot_ra_pumpage(df):
    wfname = df.Wellfield.values

    fig, axes = plt.subplots(2, 1, figsize=(13, 16))
    sns.barplot(x='Wellfield', y='WF_Pumpage', hue='RA Period', data=df, ax=axes[0])
    # sns.barplot(x='Wellfield', y='WF_Pumpage', hue='RA Period', data=tempDF)

    axes[0].set_ylabel('Pumpage, mgd', fontsize=AX_LABEL_FONTSIZE)
    axes[0].set_title(f'By RA-Period - {wfname}', fontsize=TITLE_FONTSIZE)

    plt.tight_layout()

    svfilePath = os.path.join(D_PROJECT,'plotWarehouse',f'RA_{wfname[0]}-{wfname[1]}')
    fig.savefig(svfilePath, facecolor='auto', edgecolor='auto', bbox_inches='tight')
    fig.savefig(svfilePath+'.pdf', facecolor='auto', edgecolor='auto', orientation="portrait"
        , bbox_inches='tight')

    plt.show(block=False)
    fig.clf()
    plt.close()
    return

if __name__ == '__main__':
    sns.set_theme(style="darkgrid")
    plt.rcParams.update({'font.size': 8, 'savefig.dpi': 300})
    conn = LoadData.get_DBconn()
    df = pd.read_sql('''
        --begin-sql
        select A.Wellfield, CAST(A.Date as Date) [Date], A.WF_Pumpage, A.StdPumpage, PctOfCWUP, StdPctOfCWUP
        from (
            -- Monthly WF pumpage
            select A.Wellfield, A.Date, AVG(A.WF_Pumpage) WF_Pumpage, STDEV(A.WF_Pumpage) StdPumpage
                , AVG(A.PctOfCWUP) PctOfCWUP, STDEV(A.PctOfCWUP) StdPctOfCWUP
            from (
            select A.Wellfield, A.MonthStart [Date], A.WF_Pumpage, A.WF_Pumpage/B.WF_Pumpage*100. PctOfCWUP
            from (
                -- Daily WF pumpage
                select OROP_WFCode Wellfield, TSTAMP Date, sum(DailyPumpage) WF_Pumpage, TS.dbo.MonthStart(TSTAMP) MonthStart
                from [dbo].[RA_DailyPumpage]
                where OROP_WFCode in ('CBR','CYC','CYB','MRB','EDW','STK')
                group by OROP_WFCode, TSTAMP
                union
                -- Add CWUP
                select 'CWUP' Wellfield, TSTAMP Date, sum(DailyPumpage) WF_Pumpage, TS.dbo.MonthStart(TSTAMP) MonthStart
                from [dbo].[RA_DailyPumpage]
                where OROP_WFCode not in ('BUD','SCH')
                group by TSTAMP
            ) A
            left join (
                select 'CWUP' Wellfield, TSTAMP Date, sum(DailyPumpage) WF_Pumpage, TS.dbo.MonthStart(TSTAMP) MonthStart
                from [dbo].[RA_DailyPumpage]
                where OROP_WFCode not in ('BUD','SCH')
                group by TSTAMP
            ) B on A.Date=B.Date
            ) A
            group by A.Wellfield,A.Date
        ) A
        order by Wellfield, [Date]
    ''', conn)

    wyDF = pd.read_sql('''
        SELECT TS.dbo.WateryearStart([Date]) [Date],Wellfield
            ,AVG(WF_Pumpage) WF_Pumpage,STDEV(WF_Pumpage) StdPumpage
        FROM (
            -- Daily WF pumpage
            SELECT TSTAMP [Date],OROP_WFCode Wellfield,SUM(DailyPumpage) WF_Pumpage
            FROM [dbo].[RA_DailyPumpage]
            WHERE OROP_WFCode in ('CBR','CYC','CYB','MRB','EDW','STK')
            GROUP BY TSTAMP,OROP_WFCode
        ) A
        GROUP BY TS.dbo.WateryearStart([Date]),Wellfield
        ORDER BY Wellfield,[Date]
    ''', conn)

    raDF = pd.read_sql('''
        --begin-sql
        SELECT OROP_WFCode Wellfield,WYStart Date,AVG(WFPumpage) WF_Pumpage,STDEV(WFPumpage) AnnualSTD
        , case when WYStart between '10/01/2007' and '09/30/2013' then 'RA First SixYrs'
            else case when WYStart between '10/01/2013' and '09/30/2019' then 'RA Last SixYrs'
                else case when WYStart between '10/01/2019' and '09/30/2023' then 'RA Extended Period'
                    else NULL
        end end end [RA Period]
        FROM (
            -- Wellfield Pumpage
            SELECT TSTAMP [Date],OROP_WFCode,SUM(DailyPumpage) WFPumpage,TS.dbo.WateryearStart([TSTAMP]) WYStart
            FROM [dbo].[RA_DailyPumpage]
            WHERE OROP_WFCode in ('CBR','CYC','CYB','MRB','EDW','STK')
            GROUP BY TSTAMP,OROP_WFCode

            --ORDER BY TSTAMP,OROP_WFCode
        ) A
        --where OROP_WFCode='EDW',OROP_WFCode,
        GROUP BY OROP_WFCode,WYStart
        ORDER BY OROP_WFCode,WYStart
    ''', conn)
    conn.close()

    # plot by RA period
    plot_ra_pumpage(raDF)
    svfilePath = os.path.join(D_PROJECT,'plotWarehouse','RA Period Pumpage.csv')
    raDF.to_csv(svfilePath, index=False)

    # plot monthly timeseries and ACF-PACF
    tempDF = df[['Wellfield','Date','WF_Pumpage','StdPumpage']]
    [plot_wf_pumpage_ts(tempDF[tempDF['Wellfield']==i],'Monthly Pumpage')
        for i in ['CBR','CYC','CYB','MRB','EDW','STK','CWUP']
    ]

    # plot Percent of CWUP
    tempDF = df[['Wellfield','Date','PctOfCWUP','StdPctOfCWUP']].rename(
        columns={'PctOfCWUP':'WF_Pumpage','StdPctOfCWUP':'StdPumpage'})
    [plot_wf_pumpage_ts(tempDF[tempDF['Wellfield']==i],'Pct-of-CWUP')
        for i in ['CBR','CYC','CYB','MRB','EDW','STK']
    ]
    svfilePath = os.path.join(D_PROJECT,'plotWarehouse','Monthly Pumpage.csv')
    df.to_csv(svfilePath, index=False)

    # plot with WY aggregation
    [plot_wf_pumpage_ts1([wyDF[wyDF['Wellfield']==i],wyDF[wyDF['Wellfield']==j]],'WY Pumpage')
        for i,j in zip(
            ['CBR','CYB','EDW'],
            ['CYC','MRB','STK']
        )]
    svfilePath = os.path.join(D_PROJECT,'plotWarehouse','WY Pumpage.csv')
    wyDF.to_csv(svfilePath, index=False)

    # plot by RA period
    [plot_ra_pumpage(raDF[raDF['Wellfield']==i])
        for i in ['CBR','CYC','CYB','MRB','EDW','STK']
    ]
    svfilePath = os.path.join(D_PROJECT,'plotWarehouse','RA Period Pumpage.csv')
    raDF.to_csv(svfilePath, index=False)

    exit(0)