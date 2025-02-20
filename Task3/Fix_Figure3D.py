import os
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.transforms import Bbox
import seaborn as sns
import LoadData

FIG_TITLE_FONTSIZE = 16
TITLE_FONTSIZE = 14
AX_LABEL_FONTSIZE = 12

D_PROJECT = os.path.dirname(__file__)


def plot_onesite(df):
    wname = [df[0].PointName.values[0],df[1].PointName.values[0]]

    fig, axes = plt.subplots(2, 1, figsize=(13, 16))

    df[0] = df[0].drop('PointName', axis=1)
    g = sns.lineplot(ax=axes[0], x='Date', y='Value', data=df[0], hue='SeriesName',
        style='SeriesName', dashes=[(1,0),(1,0),(1,0),(3,1)], palette='tab10')
    axes[0].set_xlabel("Date", fontsize=AX_LABEL_FONTSIZE)
    axes[0].set_ylabel('Waterlevel, ft NGVD', fontsize=AX_LABEL_FONTSIZE)
    axes[0].set_title(f'{wname[0]}', fontsize=TITLE_FONTSIZE)

    xreg = [pd.to_datetime('2013-10-01'), pd.to_datetime('2019-09-30')]
    axes[0].axvspan(xreg[0], xreg[1], color='cyan', alpha=0.2, label='2nd Six-year RA')

    df[1] = df[1].drop('PointName', axis=1)
    g = sns.lineplot(ax=axes[1], x='Date', y='Value', data=df[1], hue='SeriesName',
        style='SeriesName', dashes=[(1,0),(1,0),(1,0),(3,1)], palette='tab10')
    axes[1].set_xlabel("Date", fontsize=AX_LABEL_FONTSIZE)
    axes[1].set_ylabel('Waterlevel, ft NGVD', fontsize=AX_LABEL_FONTSIZE)
    axes[1].set_title(f'{wname[1]}', fontsize=TITLE_FONTSIZE)

    axes[1].axvspan(xreg[0], xreg[1], color='cyan', alpha=0.3, label='2nd Six-year RA')

    plt.tight_layout()

    svfilePath = os.path.join(D_PROJECT,'plotWarehouse',f'Figure3D_{wname[0]}')
    fig.savefig(svfilePath, facecolor='auto', edgecolor='auto', bbox_inches='tight')
        # , bbox_inches=Bbox([[0,0],[6.5,8]]))
    fig.savefig(svfilePath+'.pdf', facecolor='auto', edgecolor='auto', orientation="portrait"
        , bbox_inches='tight')
        # , bbox_inches=Bbox([[1,1],[7.5,9]]))
    plt.show(block=False)
    fig.clf()
    plt.close()
    return


if __name__ == '__main__':
    sns.set_theme(style="darkgrid")
    plt.rcParams.update({'font.size': 8, 'savefig.dpi': 300})
    conn = LoadData.get_DBconn()
    df = pd.read_sql(f'''
        SELECT A.[PointName], A.[WeekStartDate] [Date]
            , A.WeeklyWaterlevel [Weekly Waterlevel]
            , [OneYr_MVMED] [One-year Moving Median]
            , [EightYr_MVMED] [Eight-year Moving Median]
            , C.TargetWL [Target Waterlevel]
            , case when A.[WeekStartDate] between '10/01/2007' and '09/30/2013' then 'RA_1stSixYrs'
                else case when A.[WeekStartDate] between '10/01/2013' and '09/30/2019' then 'RA_2ndSixYrs'
                    else case when A.[WeekStartDate] between '10/01/2019' and '09/30/2023' then 'RA_Extended'
                        else NULL
        end end end RA_Period      
        FROM [dbo].[RA_SAS_WeeklyWL] A
        inner join [dbo].[RA_SAS_WeeklyWL_MVMED] B 
            ON A.PointName=B.PointName AND A.WeekStartDate=B.WeekStartDate
        LEFT JOIN [dbo].[RA_TargetWL] C on A.PointName=C.PointName
        where A.PointName in ('Cosme-20s','EW-11s','Jacksn26As','StPt-47s','EW-SM-15','CWD-Elem-SAS')
        ORDER BY A.PointName,A.WeekStartDate
    ''', conn)
    conn.close()

    tempDF = pd.melt(df[['PointName','Date',
        'Weekly Waterlevel','One-year Moving Median','Eight-year Moving Median','Target Waterlevel']]
        , id_vars=['PointName','Date']
        , var_name='SeriesName', value_name='Value', value_vars=[
            'Weekly Waterlevel','One-year Moving Median','Eight-year Moving Median','Target Waterlevel'
            ])

    [plot_onesite([tempDF[tempDF['PointName']==i],tempDF[tempDF['PointName']==j]])
        for i,j in zip(
            ['Cosme-20s','Jacksn26As','EW-SM-15'],
            ['EW-11s','StPt-47s','CWD-Elem-SAS']
        )]
