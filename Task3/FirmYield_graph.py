import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.transforms import Bbox
import seaborn as sns
from statsmodels.graphics.tsaplots import plot_acf, plot_pacf
import LoadData

FIG_TITLE_FONTSIZE = 14
TITLE_FONTSIZE = 12
AX_LABEL_FONTSIZE = 10

D_PROJECT = os.path.dirname(__file__)


def plot_wf_pumpage_ts(df,int_stats):
    wfname = df.Wellfield.values[0]

    fig, axes = plt.subplots(3, 1, figsize=(13, 16))
    fig.suptitle(f'{int_stats} - {wfname}'
        , fontsize=FIG_TITLE_FONTSIZE, fontweight='bold', y=1.02)

    df = df.drop('Wellfield', axis=1)
    sns.lineplot(ax=axes[0], x='Date', y='WF_Pumpage', data=df, label='Avg Point from daily data')
    df['lower'] = df['WF_Pumpage']-0.5*df['StdPumpage']
    df['upper'] = df['WF_Pumpage']+0.5*df['StdPumpage']
    axes[0].fill_between(df['Date'], df['lower'], df['upper'], color='lightblue', alpha=0.9
        , label='Point Stdev about the mean')

    axes[0].set_xlabel("Date", fontsize=AX_LABEL_FONTSIZE)
    axes[0].set_ylabel(int_stats, fontsize=AX_LABEL_FONTSIZE)

    axes[0].axvspan('2013-10-01', '2019-09-30', color='yellow', alpha=0.4, label='The second 6-year RA period')
    mean_value = df['WF_Pumpage'].mean()
    stdev_value = df['WF_Pumpage'].std()
    yreg = [mean_value-stdev_value*0.5, mean_value+stdev_value*0.5]
    axes[0].axhspan(yreg[0], yreg[1], color='grey', alpha=0.3, label='Stdev about the grand mean')
    ylim = axes[0].get_ylim()
    axes[0].set_ylim([0,ylim[1]])
    title = f'Timeseries Plot - Grand Mean {mean_value:.2f}, Stdev {stdev_value:.2f}'
    axes[0].set_title(title, fontsize=TITLE_FONTSIZE)
    axes[0].legend()

    # Plot ACF in the middle subplot
    plot_acf(df['WF_Pumpage'], lags= 60, ax=axes[1], title='Autocorrelation Function (ACF) with 95% CI')

    # Plot PACF in the bottom subplot
    plot_pacf(df['WF_Pumpage'], lags= 60, ax=axes[2], title='Partial Autocorrelation Function (PACF) with 95% CI', method='ywm')

    plt.tight_layout()

    svfilePath = os.path.join(D_PROJECT,'plotWarehouse',f'{int_stats}_{wfname}')
    fig.savefig(svfilePath, facecolor='auto', edgecolor='auto', bbox_inches='tight')
    fig.savefig(svfilePath+'.pdf', facecolor='auto', edgecolor='auto', orientation="portrait"
        , bbox_inches='tight', pad_inches=1)

    plt.show(block=False)
    fig.clf()
    plt.close()
    return

def plot_wf_pumpage_ts1(df,int_stats):
    wfname = [df[0].Wellfield.values[0],df[1].Wellfield.values[0]]

    fig, axes = plt.subplots(2, 1, figsize=(13, 16))
    fig.suptitle(f'{int_stats} - {wfname[0]} & {wfname[1]}'
        , fontsize=FIG_TITLE_FONTSIZE, fontweight='bold', y=1.02)

    df[0] = df[0].drop('Wellfield', axis=1)
    sns.lineplot(ax=axes[0], x='Date', y='WF_Pumpage', data=df[0], label='Avg Point from daily data')
    df[0]['lower'] = df[0]['WF_Pumpage']-0.5*df[0]['StdPumpage']
    df[0]['upper'] = df[0]['WF_Pumpage']+0.5*df[0]['StdPumpage']
    axes[0].fill_between(df[0]['Date'], df[0]['lower'], df[0]['upper'], color='lightblue', alpha=0.9
        , label='Point Stdev about the mean')

    axes[0].set_xlabel("Date", fontsize=AX_LABEL_FONTSIZE)
    axes[0].set_ylabel('Pumpage, mgd', fontsize=AX_LABEL_FONTSIZE)

    axes[0].axvspan('2013-10-01', '2019-09-30', color='yellow', alpha=0.4, label='The second 6-year RA period')
    mean_value = df[0]['WF_Pumpage'].mean()
    stdev_value = df[0]['WF_Pumpage'].std()
    yreg = [mean_value-stdev_value*0.5, mean_value+stdev_value*0.5]
    axes[0].axhspan(yreg[0], yreg[1], color='grey', alpha=0.3, label='Stdev about the grand mean')
    ylim = axes[0].get_ylim()
    axes[0].set_ylim([0,ylim[1]])
    title = f'{wfname[0]} - Grand Mean {mean_value:.2f}, Stdev {stdev_value:.2f}'
    axes[0].set_title(title, fontsize=TITLE_FONTSIZE)
    axes[0].legend()

    df[1] = df[1].drop('Wellfield', axis=1)
    sns.lineplot(ax=axes[1], x='Date', y='WF_Pumpage', data=df[1], label='Avg Point from daily data')
    df[1]['lower'] = df[1]['WF_Pumpage']-0.5*df[1]['StdPumpage']
    df[1]['upper'] = df[1]['WF_Pumpage']+0.5*df[1]['StdPumpage']
    axes[1].fill_between(df[1]['Date'], df[1]['lower'], df[1]['upper'], color='lightblue', alpha=0.9
        , label='Point Stdev about the mean')

    axes[1].set_xlabel("Date", fontsize=AX_LABEL_FONTSIZE)
    axes[1].set_ylabel(int_stats, fontsize=AX_LABEL_FONTSIZE)

    axes[1].axvspan('2013-10-01', '2019-09-30', color='yellow', alpha=0.4, label='The second 6-year RA period')
    mean_value = df[1]['WF_Pumpage'].mean()
    stdev_value = df[1]['WF_Pumpage'].std()
    yreg = [mean_value-stdev_value*0.5, mean_value+stdev_value*0.5]
    axes[1].axhspan(yreg[0], yreg[1], color='grey', alpha=0.3, label='Stdev about the grand mean')
    ylim = axes[1].get_ylim()
    axes[1].set_ylim([0,ylim[1]])
    title = f'{wfname[1]} - Grand Mean {mean_value:.2f}, Stdev {stdev_value:.2f}'
    axes[1].set_title(title, fontsize=TITLE_FONTSIZE)
    axes[0].legend()

    plt.tight_layout()

    svfilePath = os.path.join(D_PROJECT,'plotWarehouse',f'{int_stats}_{wfname[0]}-{wfname[1]}')
    fig.savefig(svfilePath, facecolor='auto', edgecolor='auto', bbox_inches='tight')
    fig.savefig(svfilePath+'.pdf', facecolor='auto', edgecolor='auto', orientation="portrait"
        , bbox_inches='tight', pad_inches=1)

    plt.show(block=False)
    fig.clf()
    plt.close()
    return

def plot_ra_pumpage(df):
    fig, axes = plt.subplots(2, 1, figsize=(13, 16))
    fig.suptitle('By Wellfield and RA Period'
        , fontsize=FIG_TITLE_FONTSIZE, fontweight='bold', y=1.02)

    sns.barplot(x='Wellfield', y='WF_Pumpage', hue='RA Period', data=df, ax=axes[0])
    axes[0].set_ylabel('Pumpage, mgd', fontsize=AX_LABEL_FONTSIZE)
    axes[0].set_title('Average Pumpage', fontsize=TITLE_FONTSIZE)

    sns.barplot(x='Wellfield', y='PctOfCWUP', hue='RA Period', data=df, ax=axes[1])
    axes[1].set_ylabel('Percent of CWUP', fontsize=AX_LABEL_FONTSIZE)
    axes[1].set_title('Percentage of CWUP Total', fontsize=TITLE_FONTSIZE)

    plt.tight_layout()

    svfilePath = os.path.join(D_PROJECT,'plotWarehouse','RA_BarPlot')
    fig.savefig(svfilePath, facecolor='auto', edgecolor='auto', bbox_inches='tight')
    fig.savefig(svfilePath+'.pdf', facecolor='auto', edgecolor='auto', orientation="portrait"
        , bbox_inches='tight', pad_inches=1)

    plt.show(block=False)
    fig.clf()
    plt.close()
    return

def plot_ra_violin(df):
    tempDF = df[df['RA Period']!='RA First SixYrs'][df['Wellfield']!='CWUP']
    g = sns.catplot(tempDF, x='Wellfield', y='WF_Pumpage', hue='RA Period'
        , kind='violin', split=True, palette='pastel', height=13, aspect=0.8125)
    g.set_axis_labels('Wellfield', 'Pumpage, mgd', fontsize=AX_LABEL_FONTSIZE)
    g.figure.suptitle('Water Year WF Pumpage - Violin Plot (Box and histogram plots)'
        , fontsize=FIG_TITLE_FONTSIZE, y=1.03) # Adjust y for title position

    plt.legend(title="RA Period", loc='upper right')
    g._legend.remove()

    # # Create custom legend
    # handles, labels = g.ax.get_legend_handles_labels()
    # g.ax.legend(handles, ['RA Second SixYrs', 'RA Extended Period'], title='RA Period', loc='upper right')

    plt.tight_layout()

    svfilePath = os.path.join(D_PROJECT,'plotWarehouse',f'RA_2PeriodCompare')
    plt.savefig(svfilePath, facecolor='auto', edgecolor='auto', bbox_inches='tight')
    plt.savefig(svfilePath+'.pdf', facecolor='auto', edgecolor='auto', orientation="landscape"
        , bbox_inches='tight', pad_inches=1)

    plt.show(block=False)
    plt.clf()
    plt.close()
    return

def plot_ra_pctmax(df):
    fig, axes = plt.subplots(2, 1, figsize=(13, 16))
    fig.suptitle('Percentage of WF Max Pumpage by RA Period'
        , fontsize=FIG_TITLE_FONTSIZE, fontweight='bold', y=1.02) # Adjust y for title position

    sns.barplot(x='Wellfield', y='PctOfWFMax', hue='RA Period', data=df, ax=axes[0])
    axes[0].set_ylabel('Percent of Max RA Period, mgd', fontsize=AX_LABEL_FONTSIZE)
    axes[0].set_title('Percentage of Wellfield Max over RA Period', fontsize=TITLE_FONTSIZE)

    sns.barplot(x='Wellfield', y='PctOfWFMax_RA', hue='RA Period', data=df, ax=axes[1])
    axes[1].set_ylabel('Percent of Max for Each RA Intervals', fontsize=AX_LABEL_FONTSIZE)
    axes[1].set_title('Percentage of Wellfield Max over Each RA Period', fontsize=TITLE_FONTSIZE)

    plt.tight_layout()

    svfilePath = os.path.join(D_PROJECT,'plotWarehouse','RA_PctMax')
    fig.savefig(svfilePath, facecolor='auto', edgecolor='auto', bbox_inches='tight')
    fig.savefig(svfilePath+'.pdf', facecolor='auto', edgecolor='auto', orientation="portrait"
        , bbox_inches='tight', pad_inches=1)

    plt.show(block=False)
    fig.clf()
    plt.close()
    return


if __name__ == '__main__':
    from image2pdf import merge_pdf
    # merge_pdf(D_PROJECT)

    sns.set_theme(style="darkgrid")
    plt.rcParams.update({'font.size': 8, 'savefig.dpi': 300, 'savefig.orientation': 'portrait'
        , 'savefig.bbox': 'standard'})
    conn = LoadData.get_DBconn()
    df = pd.read_sql('''
        --begin-sql
        select Wellfield, CAST([Date] as Date) [Date], WF_Pumpage, StdPumpage, PctOfCWUP, StdPctOfCWUP
        , case when Date between '10/01/2007' and '09/30/2013' then 'RA First SixYrs'
            else case when Date between '10/01/2013' and '09/30/2019' then 'RA Second SixYrs'
                else case when Date between '10/01/2019' and '09/30/2023' then 'RA Extended Period'
                    else NULL
        end end end [RA Period]
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
                where OROP_WFCode in ('CBR','CYC','CYB','MRB','EDW','STK','SPC','NWH','COS','S21')
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
            WHERE OROP_WFCode in ('CBR','CYC','CYB','MRB','EDW','STK','SPC','NWH','COS','S21')
            GROUP BY TSTAMP,OROP_WFCode
        ) A
        GROUP BY TS.dbo.WateryearStart([Date]),Wellfield
        ORDER BY Wellfield,[Date]
    ''', conn)

    raDF = pd.read_sql('''
        --begin-sql
        SELECT 
        case when WYStart between '10/01/2007' and '09/30/2013' then 'RA First SixYrs'
            else case when WYStart between '10/01/2013' and '09/30/2019' then 'RA Second SixYrs'
                else case when WYStart between '10/01/2019' and '09/30/2023' then 'RA Extended Period'
                    else NULL
        end end end [RA Period]
        , Wellfield, CAST(WYStart as Date) [Date]
        , AVG(WF_Pumpage) WF_Pumpage, STDEV(WF_Pumpage) AnnualSTD
        , AVG(PctOfCWUP) PctOfCWUP, STDEV(PctOfCWUP) StdPctOfCWUP
        FROM (
            select A.Wellfield, TS.dbo.WateryearStart(A.Date) WYStart, A.WF_Pumpage, A.WF_Pumpage/B.WF_Pumpage*100. PctOfCWUP
            from (
                -- Daily WF pumpage
                select OROP_WFCode Wellfield, TSTAMP Date, sum(DailyPumpage) WF_Pumpage
                from [dbo].[RA_DailyPumpage]
                where OROP_WFCode in ('CBR','CYC','CYB','MRB','EDW','STK','SPC','NWH','COS','S21')
                group by OROP_WFCode, TSTAMP
                union
                -- Add CWUP
                select 'CWUP' Wellfield, TSTAMP Date, sum(DailyPumpage) WF_Pumpage
                from [dbo].[RA_DailyPumpage]
                where OROP_WFCode not in ('BUD','SCH')
                group by TSTAMP
            ) A
            left join (
                select 'CWUP' Wellfield, TSTAMP Date, sum(DailyPumpage) WF_Pumpage
                from [dbo].[RA_DailyPumpage]
                where OROP_WFCode not in ('BUD','SCH')
                group by TSTAMP
            ) B on A.Date=B.Date
            --order by wellfield,A.date
        ) A
        where Wellfield<>'CWUP'
        GROUP BY Wellfield,WYStart
        ORDER BY Wellfield,WYStart
    ''', conn)

    saswlDF = pd.read_sql('''
        SELECT MonthStart [Date],PointName, AVG(DailyWaterlevel) MonthlyWaterlevel, STDEV(DailyWaterlevel) StdWaterlevel
        FROM (
            SELECT [TSTAMP],PointName,[DailyWaterlevel],TS.dbo.MonthStart([TSTAMP]) MonthStart
            FROM [dbo].[RA_SAS_DailyWL]
        ) A
        GROUP BY MonthStart,PointName
        ORDER BY PointName,[Date]
    ''', conn)

    conn.close()

    # plot a few SAS well to check ACF and PACF
    tempDF = saswlDF.rename(columns={
        'PointName':'Wellfield','MonthlyWaterlevel':'WF_Pumpage','StdWaterlevel':'StdPumpage'})
    [plot_wf_pumpage_ts(tempDF[tempDF['Wellfield']==i],'Monthly Waterlevel')
        for i in ['SERW-s','StPt-47s','EW-SM-15']
    ]

    # plot monthly timeseries and ACF-PACF
    tempDF = df[['Wellfield','Date','WF_Pumpage','StdPumpage']]
    [plot_wf_pumpage_ts(tempDF[tempDF['Wellfield']==i],'Monthly Pumpage')
        for i in ['CBR','CYC','CYB','MRB','EDW','STK','SPC','NWH','COS','S21','CWUP']
    ]

    # plot Percent of CWUP
    tempDF = df[['Wellfield','Date','PctOfCWUP','StdPctOfCWUP']].rename(
        columns={'PctOfCWUP':'WF_Pumpage','StdPctOfCWUP':'StdPumpage'})
    [plot_wf_pumpage_ts(tempDF[tempDF['Wellfield']==i],'Pct-of-CWUP')
        for i in ['CBR','CYC','CYB','MRB','EDW','STK','SPC','NWH','COS','S21']
    ]
    svfilePath = os.path.join(D_PROJECT,'plotWarehouse','Monthly Pumpage.csv')
    df.to_csv(svfilePath, index=False)

    # plot with WY aggregation
    [plot_wf_pumpage_ts1([wyDF[wyDF['Wellfield']==i],wyDF[wyDF['Wellfield']==j]],'WY Pumpage')
        for i,j in zip(
            ['CBR','CYB','EDW','SPC','COS'],
            ['CYC','MRB','STK','S21','NWH']
        )]
    svfilePath = os.path.join(D_PROJECT,'plotWarehouse','WY Pumpage.csv')
    wyDF.to_csv(svfilePath, index=False)

    # plot by RA period
    plot_ra_pumpage(raDF)
    svfilePath = os.path.join(D_PROJECT,'plotWarehouse','RA Period Pumpage.csv')
    raDF.to_csv(svfilePath, index=False)

    tempDF = df[df['Wellfield']!='STK'][['Wellfield','Date','WF_Pumpage','RA Period']]
    plot_ra_violin(tempDF)

    # firm yield - sustained max GW production
    tempDF = raDF[raDF['Wellfield']!='NPC'][['RA Period','Wellfield','Date','WF_Pumpage']]
    wf_max = tempDF.groupby('Wellfield')['WF_Pumpage'].transform('max')
    tempDF.loc[:,'PctOfWFMax'] = (tempDF['WF_Pumpage'] / wf_max) * 100
    wf_max = tempDF.groupby(['Wellfield','RA Period'])['WF_Pumpage'].transform('max')
    tempDF.loc[:,'PctOfWFMax_RA'] = (tempDF['WF_Pumpage'] / wf_max) * 100
    tempDF.dropna(inplace=True)
    tempDF = tempDF[tempDF['PctOfWFMax_RA']!=pd.notna]
    plot_ra_pctmax(tempDF)

    def check_probability(df, val_col, grp_cols, threshold=80, confidence_level=0.9):
        """
        Calculates if there's a 90% chance that values in 'val_col' are greater than or equal to 'threshold' 
        within each group defined by 'grp_cols'. 
        
        Args:
            df: Pandas DataFrame
            val_col: Name of the column to check values against
            grp_cols: List of grouping columns
            threshold: Value to compare against in 'val_col'
            confidence_level: Desired confidence level (decimal)
        
        Returns:
            A Pandas Series with the calculated probabilities for each group
        """
        
        grouped = df.groupby(grp_cols)[val_col]
        result = grouped.apply(lambda x: (x >= threshold).mean() >= confidence_level)
        return result

    tempDF['C1gt80'] = 0
    tempDF.loc[tempDF['PctOfWFMax']>=80.,'C1gt80'] = 1
    tempDF['C2gt85'] = 0
    tempDF.loc[tempDF['PctOfWFMax_RA']>=85.,'C2gt85'] = 1
    print(tempDF.groupby(['RA Period','Wellfield'])['C2gt85'].mean()*100.)

    print(check_probability(tempDF,'PctOfWFMax',['RA Period','Wellfield'],70))
    print(check_probability(tempDF,'PctOfWFMax_RA',['RA Period','Wellfield'],70))

    svfilePath = os.path.join(D_PROJECT,'plotWarehouse','RA Period PctMax.csv')
    tempDF.to_csv(svfilePath, index=False)

    # merge all pdf files
    merge_pdf(D_PROJECT)

    exit(0)