#!/Users/wanakule/opt/anaconda3/envs/mwp_cwf/bin/python
# import arcpy
import pyodbc
import pandas as pd
import os
import sys
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sbn
import argparse
import warnings
from datetime import datetime


def PlotHydrograph(datatype,loc,timestep):
    """Script code goes below"""
    dv = '{SQL Server}'
    sv = 'vgridfs'
    db = 'MWP_CWF'
    d_csv = 'F:\MWP_CWF\Task3_3\MWP_CWF_csv'
    conn = pyodbc.connect(
        f'DRIVER={dv};SERVER={sv};Database={db};Trusted_Connection=Yes',autocommit=True)
    sdate = '10/1/2007'
    edate = '9/30/2023'
    
    fig = plotOneData(conn,datatype,loc,timestep,sdate,edate)

    '''
    # test data
    pointname = [
        ['sas','A-1s'],
        ['ufas','Calm-33A'],
        ['pmp','CB-15'],
        ['str','HILLS R AT MORRIS BRIDGE'],
        ['spr','Sulphur Springs']
    ]
    for l in pointname:
        plotOneData(l[0],l[1],'Daily',sdate,edate)
        plotOneData(l[0],l[1],'Weekly',sdate,edate)
    '''
    conn.close()

    return fig

'''
def getSelectedFeatures(layer_name,namefield):
    mapView = map.defaultView

    # Get the layer from which you want to retrieve selected features
    layer = map.listLayers(layer_name)[0]

    # Get the selected features
    selected_features = layer.getSelectionSet()

    # Iterate over the selected features and print their attributes
    for feature in selected_features:
        location_name = feature[namefield]
        arcpy.AddMessage(location_name)

def getLocByDatatype(datatype):
    # datatype: 'sas' or ufas for groundwater level
    #           'pmp for pumpage
    #           'spr' for spring flow
    #           'str' for streamflow
    #           'ddn1' for streamflow
    arcpy.env.workspace = 'F:\MWP_CWF\Task3_3\ArcGIS\Hydrograph\PlotHydrograph.gdb'
    match datatype:
        case 'pmp':
            fc = 'TBW_ProductionWells'
            field = "WellName"
        case 'sas':
            fc = 'OROP_SASwells'
            field = "WellName"
        case 'ufas':
            fc = 'OROP_UFASwells'
            field = "PointName"
        case 'spr':
            fc = "Spring"
            field = "Name"
        case 'str':
            fc = "INTB_FlowGage"
            field = "StationNam"
        case 'ddn1': # DDN in SAS
            fc = "SASgrid_centroid"
            field = "GRIDID"
        case _:
            fc = ""
            field = ""

    cursor = arcpy.SearchCursor(fc)
    locList = []
    for row in cursor:
        locList += [row.getValue(field)]

    return locList
'''

''' Start Plot Module '''
def moving_median(data, wd_size):
    """Calculates the moving median of a series, handling missing values."""
    result = []
    for i in range(len(data)):
        wd = data[max(0, i - wd_size + 1): i + 1]
        wd = [x for x in wd if not np.isnan(x)]  # Remove NaNs
        if wd:
            result.append(np.median(wd))
        else:
            result.append(np.nan)  # If the window is empty (all NaNs), append NaN
    return result

def sql_pumpage(pointname,timestep,sdate,edate):
    # Daily and Weekly Pumpage
    if timestep=='Weekly':
        datename = 'WeekStartDate'
        mav_colname1 = 'FiftytwoWeek_MAV'
        mav_heading1 = '52-week Moving Average'
        mav_heading2 = 'CWF 52-week Moving Avg'
    elif timestep=='Daily':
        datename = 'TSTAMP'
        mav_colname1 = 'OneYear_MAV'
        mav_heading1 = 'One-year Moving Average'
        mav_heading2 = 'CWF One-year Moving Avg'

    sql = f'''
        SELECT A.{datename} [Date],
            A.{timestep}Pumpage [{timestep} Pumpage],
            B.[CWF {timestep}Pumpage],
            A.{mav_colname1} [{mav_heading1}],
            B.[{mav_heading2}]
        FROM [dbo].[RA_{timestep}Pumpage] A
        INNER JOIN (
            SELECT DiSTINCT [{datename}]
                ,sum([{timestep}Pumpage]) OVER(PARTITION BY {datename}) [CWF {timestep}Pumpage]
                ,sum([{mav_colname1}]) OVER(PARTITION BY {datename}) [{mav_heading2}]
            FROM [dbo].[RA_{timestep}Pumpage]
            WHERE OROP_WFCode IN ('CBR','COS','CYB','CYC','EDW','MRB','NPC','NWH','S21','SPC','STK') 
        ) B ON A.{datename}=B.{datename} and A.SCADAName='{pointname}' 
        WHERE A.{datename} BETWEEN '{sdate}' AND '{edate}'
        ORDER BY [Date]
    '''
    # if 'arcpy' in sys.modules:
    #     arcpy.AddMessage(f'SQL = \n{sql}')
    # else:
    #     print(f'SQL = \n{sql}')

    return sql

def sql_gwWL(aquifer,pointname,timestep,sdate,edate):
    # Daily and Weekly Groundwater Head
    sql = f'''
        select TSTAMP [Date],{timestep}Waterlevel Value
        from [dbo].[RA_{aquifer}_{timestep}WL]
        where PointName='{pointname}' and TSTAMP between DATEADD(d,-2921,'{sdate}') and '{edate}'
        order by TSTAMP
    '''
    if timestep=='Weekly':
        sql = f'''
        select A.WeekStartDate [Date],
            WeeklyWaterlevel [{timestep} Waterlevel],
            OneYr_MVMED [One-year Moving Median],
            EightYr_MVMED [Eight-year Moving Median]
        from [dbo].[RA_{aquifer}_{timestep}WL] A
        inner join [dbo].[RA_{aquifer}_{timestep}WL_MVMED] B on A.PointName=B.PointName and A.WeekStartDate=B.WeekStartDate
        where A.PointName='{pointname}' and A.WeekStartDate between '{sdate}' and '{edate}'
        order by A.WeekStartDate
        '''
    # if 'arcpy' in sys.modules:
    #     arcpy.AddMessage(f'SQL = \n{sql}')
    # else:
    #     print(f'SQL = \n{sql}')

    return sql

def sql_streamFlow(conn,pointname,timestep,sdate,edate):
    # Daily and Weekly Streamflow
    temp_sql = f'''
        select FlowStationID from FlowStation where StationName='{pointname}'
    '''
    pointid = pd.read_sql(temp_sql, conn).FlowStationID[0]
    
    match timestep:
        case 'Daily':
            sql = f'''
                select * from (
                SELECT [Date],[Value] [{timestep} Streamflow],
                    AVG([Value]) OVER(ORDER BY [Date] ROWS BETWEEN 1826 PRECEDING AND 0 FOLLOWING) [Five-year Moving Mean],
                    AVG([Value]) OVER(ORDER BY [Date] ROWS BETWEEN 3653 PRECEDING AND 0 FOLLOWING) [Ten-year Moving Mean]
                FROM [dbo].[StreamflowTimeSeries]
                where FlowStationID={pointid}
                ) A where Date between '{sdate}' and '{edate}'
                order by [DATE]
            '''
        case 'Weekly':
            sql = f'''
                select * from (
                select [Date], Value [{timestep} Streamflow],
                    AVG([Value]) OVER(ORDER BY [Date] ROWS BETWEEN 259 PRECEDING AND 0 FOLLOWING) [Five-year Moving Mean],
                    AVG([Value]) OVER(ORDER BY [Date] ROWS BETWEEN 519 PRECEDING AND 0 FOLLOWING) [Ten-year Moving Mean]
                FROM (
                    SELECT min([DATE]) Date, AVG([Value]) [Value]
                    FROM [dbo].[StreamflowTimeSeries] A
                    inner join (select distinct TSTAMP,WeeKNo from [dbo].[RA_SAS_DailyWL]) B on A.Date=B.TSTAMP
                    where FlowStationID={pointid}
                    group by WeekNo
                ) A
                ) A where Date between '{sdate}' and '{edate}'
                order by [Date]
            '''
        case 'MFL':
            sql = {}
            sql['Block5'] = f'''
                SELECT A.[Date]
                    ,MFL_FiveYrAVG,MFL_FiveYrMED
                    ,FiveYrAvg,FiveYrMed
                FROM (
                    SELECT FlowStationID,BlkNum,[Date],FiveYrAvg,FiveYrMed
                    FROM RA_BlkFlowMFL_Stats A
                    pivot (avg(Value) for StatsType in (FiveYrAvg,FiveYrMed)) B
                ) A
                INNER JOIN mfl_ts B ON A.Date=B.Date and A.FlowStationID=B.FlowStationID and A.BlkNum=B.BlockNum
                where A.BlkNum>0 and A.FlowStationID={pointid} and A.Date between '{sdate}' and '{edate}'
                ORDER BY [Date]            '''
            sql['Block10'] = f'''
                SELECT A.[Date]
                    ,MFL_TenYrAVG,MFL_TenYrMED
                    ,TenYrAvg,TenYrMed
                FROM (
                    SELECT FlowStationID,BlkNum,[Date],TenYrAvg,TenYrMed
                    FROM RA_BlkFlowMFL_Stats A
                    pivot (avg(Value) for StatsType in (TenYrAvg,TenYrMed)) B
                ) A
                INNER JOIN mfl_ts B ON A.Date=B.Date and A.FlowStationID=B.FlowStationID and A.BlkNum=B.BlockNum
                where A.BlkNum>0 and A.FlowStationID={pointid} and A.Date between '{sdate}' and '{edate}'
                ORDER BY [Date]
            '''
            sql['Annual5'] = f'''
                SELECT A.[Date]
                    ,MFL_FiveYrAVG,MFL_FiveYrMED
                    ,FiveYrAvg,FiveYrMed
                FROM (
                    SELECT FlowStationID,BlkNum,[Date],FiveYrAvg,FiveYrMed
                    FROM RA_BlkFlowMFL_Stats A
                    pivot (avg(Value) for StatsType in (FiveYrAvg,FiveYrMed)) B
                ) A
                INNER JOIN mfl_ts B ON A.Date=B.Date and A.FlowStationID=B.FlowStationID and A.BlkNum=B.BlockNum
                where A.BlkNum=0 and A.FlowStationID={pointid} and A.Date between '{sdate}' and '{edate}'
                ORDER BY [Date]
            '''
            sql['Annual10'] = f'''
                SELECT A.[Date]
                    ,MFL_TenYrAVG,MFL_TenYrMED
                    ,TenYrAvg,TenYrMed
                FROM (
                    SELECT FlowStationID,BlkNum,[Date],TenYrAvg,TenYrMed
                    FROM RA_BlkFlowMFL_Stats A
                    pivot (avg(Value) for StatsType in (TenYrAvg,TenYrMed)) B
                ) A
                INNER JOIN mfl_ts B ON A.Date=B.Date and A.FlowStationID=B.FlowStationID and A.BlkNum=B.BlockNum
                where A.BlkNum=0 and A.FlowStationID={pointid} and A.Date between '{sdate}' and '{edate}'
                ORDER BY [Date]
            '''
    return sql

def sql_springFlow(conn,pointname,timestep,sdate,edate):
    # Daily and Weekly Springflow
    temp_sql = f'''
        select SpringID from Spring where Name='{pointname}'
    '''
    pointid = pd.read_sql(temp_sql, conn).SpringID[0]

    if timestep=='Daily':
        sql = f'''
            select * from (
            SELECT [Date],[Value] [{timestep} Springflow],
                AVG([Value]) OVER(ORDER BY [Date] ROWS BETWEEN 1826 PRECEDING AND 0 FOLLOWING) [Five-year Moving Mean],
                AVG([Value]) OVER(ORDER BY [Date] ROWS BETWEEN 3653 PRECEDING AND 0 FOLLOWING) [Ten-year Moving Mean]
            FROM [dbo].[SpringflowTimeSeries]
            where SpringID={pointid}
            ) A where Date between '{sdate}' and '{edate}'
            order by [DATE]
        '''
    elif timestep=='Weekly':
        sql = f'''
            select * from (
            select [Date], Value [{timestep} Springflow],
                AVG([Value]) OVER(ORDER BY [Date] ROWS BETWEEN 259 PRECEDING AND 0 FOLLOWING) [Five-year Moving Mean],
                AVG([Value]) OVER(ORDER BY [Date] ROWS BETWEEN 519 PRECEDING AND 0 FOLLOWING) [Ten-year Moving Mean]
            FROM (
                SELECT min([DATE]) Date, AVG([Value]) [Value]
                FROM [dbo].[SpringflowTimeSeries] A
                inner join (select distinct TSTAMP,WeeKNo from [dbo].[RA_SAS_DailyWL]) B on A.Date=B.TSTAMP
                where SpringID={pointid}
                group by WeekNo
            ) A
            ) A where Date between '{sdate}' and '{edate}'
            order by [Date]

        '''
    return sql

def sql_SASdrawdown(pointid,timestep,sdate,edate):
    # expect pointid as a list of cellids
    pointList = tuple(pointid)
    ptListStr = ','.join([f'[{str(i)}]' for i in pointList])

    if timestep=='Daily':
        if 'arcpy' in sys.modules:
            arcpy.AddWarning('Drawdown data is only available in "Weekly" timestep!')
        else:
            print('Drawdown data is only available in "Weekly" timestep!')
        exit()
    sql = f'''
        select [Date],{ptListStr} from (
        select CellID,[Date],SASDDN from [dbo].[RA_sasddnTS]
        where CellID in {str(pointList)} and [Date] between '{sdate}' and '{edate}' 
        ) A pivot (max(SASDDN) for CellID in ({ptListStr})) B
        order by [Date]
    '''
    return sql

def get_DBconn(is_Windows=False):
    warnings.simplefilter(action='ignore', category=UserWarning)
    if is_Windows:
        dv = '{SQL Server}'
        sv = 'vgridfs'
        db = 'MWP_CWF'
        conn = pyodbc.connect(
            f'DRIVER={dv};SERVER={sv};Database={db};Trusted_Connection=Yes',autocommit=True)
    else:
        dv = '/opt/homebrew/Cellar/msodbcsql17/17.10.6.1/lib/libmsodbcsql.17.dylib'
        sv = 'localhost'
        db = 'MWP_CWF'
        pw = os.environ['DATABASE_SA_PASSWORD']
        conn = pyodbc.connect(
            f'DRIVER={dv};SERVER={sv};Database={db};Uid=SA;Pwd={pw}',
            autocommit=True
        )
    return conn

def plotFourData(conn,datatype,pointname,timestep,sdate,edate,q=None):
    fig = plt.gcf()
    plt.gca().remove()
    fig.set_size_inches(18, 13)
    # fig = plt.figure(figsize=(12, 8.667))
    sql = sql_streamFlow(conn,pointname,timestep,sdate,edate)
    axs = {k: fig.add_subplot(2, 2, n) for n,k in zip(range(1,5),sql.keys())}
    for k in sql.keys():
        temp_df = pd.read_sql(sql[k], conn)
        temp_df['Date'] = pd.to_datetime(temp_df['Date'])
        if temp_df is None:
            if 'argpy' in sys.modules:
                arcpy.AddError(f'No data available for this selected location "{pointname}"!')
            else:
                print(f'No data available for this selected location "{pointname}"!', file=sys.stderr)
        colnames = temp_df.columns.tolist()[1:5]
        style = {k:s for k,s in zip(colnames, [':',':','-','-'])}
        sbn.lineplot(
            ax=axs[k],
            data=pd.melt(temp_df,['Date']), x='Date', y='value', hue='variable', linewidth=0.75,
            palette=['red', 'orange', 'blue', 'green'], #dashes=style,
            # style={k:s for k,s in zip(colnames, [':',':','-','-'])},
            marker=None
        )
        axs[k].lines[0].set_linestyle('--')
        axs[k].lines[1].set_linestyle('--')
        axs[k].set_ylabel('Streamflow, cfs')
        axs[k].set_yscale('log')
        # axs[k].axvspan(pd.to_datetime('2007-10-01'), pd.to_datetime('2013-09-30'), color='yellow', alpha=0.3)
        axs[k].axvspan(pd.to_datetime('2013-10-01'), pd.to_datetime('2019-09-30'), color='cyan', alpha=0.3)
        # axs[k].axvspan(pd.to_datetime('2019-10-01'), pd.to_datetime('2023-09-30'), color='green', alpha=0.3)
        axs[k].legend().set_title(None)
        axs[k].grid(True)
        axs[k].set_title(pointname)
        # axs[k].set_xticks(rotation=0, ha='center')

    plt.tight_layout()
    proj_dir = os.path.dirname(os.path.realpath(__file__))
    svfilePath = os.path.join(proj_dir,'hydrograph_plots',f'{datatype}_{pointname}_{timestep}')
    plt.savefig(
        svfilePath,
        dpi=300, pad_inches=0.1,
        facecolor='auto', edgecolor='auto'
    )

    if q is not None:
        plt.show(block=False)
        q.put(fig)
    return

def plotOneData(datatype,pointname,timestep,sdate,edate,q=None):
    conn = get_DBconn()

    # get data from specific sql and plot
    if datatype=='ddn1':
        print(f"Processing '{datatype}: {list(pointname.keys())[0]}'")
    else:
        print(f"Processing '{datatype}: {pointname}'")

    fig = plt.figure(figsize=(13,9))
    ax = fig.add_subplot(111)
    match datatype:
        case 'sas' | 'ufas':
            if datatype=='sas':
                temp_df = pd.read_sql(f"select TargetWL from [dbo].[RA_TargetWL] where PointName='{pointname}'",conn)
                TargetWL = temp_df['TargetWL'][0]
            else:
                temp_df = pd.read_sql(f"""
                    select AvgMin TargetWL from [dbo].[RA_RegWellPermit] A where A.PointName='{pointname}'
                    UNION
                    select MinAvg TargetWL from [dbo].[swimalWL] B where B.PointName='{pointname}'
                """,conn)
                TargetWL = temp_df['TargetWL'][0]

            aquifer = datatype.upper()
            sql = sql_gwWL(aquifer,pointname,timestep,sdate,edate)
            temp_df = pd.read_sql(sql, conn)
            if temp_df is None:
                if 'argpy' in sys.modules:
                    arcpy.AddError(f'No data available for this selected location "{pointname}"!')
                else:
                    print(f'No data available for this selected location "{pointname}"!', file=sys.stderr)
            if timestep=='Daily':
                temp_df['One-year Moving Median'] = moving_median(temp_df.Value,365)
                temp_df['Eight-year Moving Median'] = moving_median(temp_df.Value,2922)
                temp_df.rename(columns={'Value': f'{timestep} Waterlevel'}, inplace=True)
                tstamp = pd.to_datetime(temp_df['Date'])
                temp_df = temp_df.loc[(tstamp >= datetime.strptime(sdate,'%m/%d/%Y')) & (tstamp <= datetime.strptime(edate,'%m/%d/%Y'))]
            temp_df['Target Waterlevel'] = [TargetWL for i in range(0,temp_df.shape[0])]
            sbn.lineplot(
                ax=ax,
                data=pd.melt(temp_df,['Date']), x='Date', y='value', hue='variable', linewidth=0.75,
                # marker='.', markeredgewidth=0, markersize=4
                marker=None
            )
            ax.lines[3].set_linestyle('--')
            [ax.lines[i].set_linewidth(1.5) for i in [1,2,3]]

            ax.set_ylabel('Waterlevel, ft')

        case 'spr':
            sql = sql_springFlow(conn,pointname,timestep,sdate,edate)
            temp_df = pd.read_sql(sql, conn)
            if temp_df is None:
                if 'argpy' in sys.modules:
                    arcpy.AddError(f'No data available for this selected location "{pointname}"!')
                else:
                    print(f'No data available for this selected location "{pointname}"!', file=sys.stderr)
            
            if pointname=='Crystal Springs':
                temp_df['5-Year Mean/Median MFL'] = [46 for i in range(0,temp_df.shape[0])]
            elif  pointname=='Sulphur Springs':
                temp_df['Minimum Flow MFL'] = [18 for i in range(0,temp_df.shape[0])]
            else:
                temp_df['Minimum Flow MFL'] = [150 for i in range(0,temp_df.shape[0])]

            sbn.lineplot(
                ax=ax,
                data=pd.melt(temp_df,['Date']), x='Date', y='value', hue='variable', linewidth=0.75,
                # marker='.', markeredgewidth=0, markersize=4
                marker=None
            )
            ax.lines[3].set_linestyle('--')
            [ax.lines[i].set_linewidth(1.5) for i in [1,2,3]]
            ax.set_ylabel('Springflow, cfs')

        case 'str':
            if timestep=='MFL':
                plotFourData(conn,datatype,pointname,timestep,sdate,edate,q)
                return
            else:
                sql = sql_streamFlow(conn,pointname,timestep,sdate,edate)
                temp_df = pd.read_sql(sql, conn)
                if temp_df is None:
                    if 'argpy' in sys.modules:
                        arcpy.AddError(f'No data available for this selected location "{pointname}"!')
                    else:
                        print(f'No data available for this selected location "{pointname}"!', file=sys.stderr)
                
                temp_df['Date'] = pd.to_datetime(temp_df['Date'])
                sbn.lineplot(
                    ax=ax,
                    data=pd.melt(temp_df,['Date']), x='Date', y='value', hue='variable', linewidth=0.75,
                    # marker='.', markeredgewidth=0, markersize=4
                    marker=None
                )
                [ax.lines[i].set_linewidth(1.5) for i in [1,2]]
                ax.set_ylabel('Streamflow, cfs')
                plt.yscale('log')
        case 'pmp': # pmp
            sql = sql_pumpage(pointname,timestep,sdate,edate)
            temp_df = pd.read_sql(sql, conn)
            temp_df['CWUP Limit'] = [90 for i in range(0,temp_df.shape[0])]
            if temp_df is None:
                if 'argpy' in sys.modules:
                    arcpy.AddError(f'No data available for this selected location "{pointname}"!')
                else:
                    print(f'No data available for this selected location "{pointname}"!', file=sys.stderr)
            colnames = temp_df.columns.tolist()
            sbn.lineplot(ax=ax, data=temp_df, x=colnames[0], y=colnames[1]
                , color='blue', linewidth=0.5, drawstyle='steps-pre', label=colnames[1])
            sbn.lineplot(ax=ax, data=temp_df, x=colnames[0], y=colnames[3]
                , color='green', linewidth=1, drawstyle='steps-pre', label=colnames[3])
            ax1 = ax.twinx()
            sbn.lineplot(ax=ax1, data=temp_df, x=colnames[0], y=colnames[2], legend=False
                , color='sienna', linewidth=0.5, drawstyle='steps-pre', label=colnames[2])
            sbn.lineplot(ax=ax1, data=temp_df, x=colnames[0], y=colnames[4], legend=False
                , color='darkorchid', linewidth=1, drawstyle='steps-pre', label=colnames[4])
            sbn.lineplot(ax=ax1, data=temp_df, x=colnames[0], y=colnames[5], legend=False
                , color='red', linewidth=1, drawstyle='steps-pre', label=colnames[5])
            ax.set_ylim(0, 15)
            ax1.set_ylim(0,150)
            # combine legend
            lines1, labels1 = ax.get_legend_handles_labels()
            lines2, labels2 = ax1.get_legend_handles_labels()
            legend = ax.legend(lines1 + lines2, labels1 + labels2, loc='upper right')
            legend1 = ax1.get_legend()
            # legend.get_frame().set_facecolor(legend1.get_frame().get_facecolor())
            # legend.get_frame().set_alpha(legend1.get_frame().get_alpha())
            legend.get_frame().set_facecolor('white')
            legend.get_frame().set_alpha(1)
            ax1.legend([],[])
            # legend1.remove()
            ax.set_ylabel('Pumpage, mgd')
            ax1.set_ylabel('Moving Average, mgd')
        case 'ddn1':
            # expect one key dictionary
            d = pointname
            pointname = list(d.keys())[0]
            sql = sql_SASdrawdown(d[pointname],timestep,sdate,edate)
            temp_df = pd.read_sql(sql, conn)
            temp_df['Date'] = pd.to_datetime(temp_df['Date'])
            if temp_df is None:
                if 'arcpy' in sys.modules:
                    arcpy.AddError(f'No data available for this selected location "{pointname}"!')
                else:
                    print(f'No data available for this selected location "{pointname}"!', file=sys.stderr)
            sbn.lineplot(
                ax=ax,
                data=pd.melt(temp_df,['Date']), x='Date', y='value', hue='variable', linewidth=0.75,
                # marker='.', markeredgewidth=0, markersize=4
                marker=None
            )
            ax.set_ylabel('Drawdown, ft')
        case _:
            if 'arcpy' in sys.modules:
                arcpy.AddError(f'No datatype "{datatype}".')
            else:
                print(f'No datatype "{datatype}".', file=sys.stderr)
        
    conn.close()
    
    legend = ax.get_legend()
    legend.set_title(None)
    legend.get_frame().set_linewidth(2)
    # legend.get_frame().set_facecolor('white')
    # legend.get_frame().set_edgecolor('black')
    legend.get_frame().set_alpha(1)
    # plt.legend().set_title(None)

    # plt.axvspan(pd.to_datetime('2007-10-01'), pd.to_datetime('2013-09-30'), color='yellow', alpha=0.3)
    plt.axvspan(pd.to_datetime('2013-10-01'), pd.to_datetime('2019-09-30'), color='cyan', alpha=0.3)
    # plt.axvspan(pd.to_datetime('2019-10-01'), pd.to_datetime('2023-09-30'), color='green', alpha=0.3)

    plt.grid(True)
    plt.title(pointname)
    plt.xticks(rotation=0, ha='center')
    plt.tight_layout()
    proj_dir = os.path.dirname(os.path.realpath(__file__))
    svfilePath = os.path.join(proj_dir,'hydrograph_plots',f'{datatype}_{pointname}_{timestep}')
    plt.savefig(
        svfilePath,
        dpi=300, pad_inches=0.1,
        facecolor='auto', edgecolor='auto'
    )
    if q is not None:
        plt.show(block=False)
        q.put(fig)
    return fig

def getValidTimestep(datatype):
    if datatype=='str':
        timestep = ['Daily','Weekly','MFL']
    elif datatype=='ddn1':
        timestep = ['Weekly']
    else:
        timestep = ['Daily','Weekly']
    
    return [t for t in arg_timestep if t in timestep]

def getDDN1cells(pts,r):
    # get INTB cells within r radius miles of a point
    import geopandas as gpd
    orop_pts = gpd.read_file(os.path.join(d_shape,'OROP_SASwells.shp'))
    orop_pts = orop_pts[[i in pts for i in orop_pts.WellName]].reset_index()
    cell_centroids =gpd.read_file(os.path.join(d_shape,'INTBgrid_centroid.shp')).reset_index()
    buff = orop_pts.buffer(r*1609.344)
    gdf = cell_centroids.sjoin(buff.to_frame(), predicate="within")
    rtnval = {
        orop_pts.WellName[i]:
        gdf[gdf.index_right==i].GRIDID.to_list()
        for i in gdf.index_right
    }

    return rtnval

def subMP(datatype,pt_list):
    import multiprocessing as mp
    """
    func_args = []
    for l in list(pointname.keys()):
        if l=='str':
            timestep = ['Daily','Weekly','MFL']
        elif l=='ddn1':
            timestep = ['Weekly']
        else:
            timestep = ['Daily','Weekly']
        for t in timestep:
            func_args += [(l,pointname[l],t,sdate,edate)]

    print(str(func_args))
    with mp.Pool(processes=4) as pool:
        results = [pool.apply(plotOneData,a) for a in func_args]
    """
    q = mp.Queue()
    procs = []
    for l in datatype:
        valid_tsteps = getValidTimestep(l)
        if l=='ddn1':
            for i in pointname[l].keys():
                for t in valid_tsteps: 
                    pn = {i:pointname[l][i]} 
                    p = mp.Process(target=plotOneData, args=(l,pn,t,sdate,edate,q))
                    procs.append(p)
                    p.start()
        else:
            for i in pointname[l]:
                for t in valid_tsteps:  
                    p = mp.Process(target=plotOneData, args=(l,i,t,sdate,edate,q))
                    procs.append(p)
                    p.start()

    rtnval = []
    for p in procs:
        rtnval.append(q.get())
    for p in procs:
        p.join()

    return rtnval

def useMP_Windows(pointname):
    bucket_sz = 40
    rtnval = []
    for l in list(pointname.keys()):
        pt_list = pointname[l]
        while len(pt_list)>0:
            rtnval += subMP([l],pt_list[1:bucket_sz])
            if len(pt_list)<bucket_sz:
                pt_list = []
            else:
                pt_list = pt_list[(bucket_sz+1):]

    return rtnval

def useMP_Mac(pointname):
    import multiprocessing as mp
    """
    func_args = []
    for l in list(pointname.keys()):
        if l=='str':
            timestep = ['Daily','Weekly','MFL']
        elif l=='ddn1':
            timestep = ['Weekly']
        else:
            timestep = ['Daily','Weekly']
        for t in timestep:
            func_args += [(l,pointname[l],t,sdate,edate)]

    print(str(func_args))
    with mp.Pool(processes=4) as pool:
        results = [pool.apply(plotOneData,a) for a in func_args]
    """
    q = mp.Queue()
    procs = []
    for l in datatype:
        valid_tsteps = getValidTimestep(l)
        if l=='ddn1':
            for i in pointname[l].keys():
                for t in valid_tsteps: 
                    pn = {i:pointname[l][i]} 
                    p = mp.Process(target=plotOneData, args=(l,pn,t,sdate,edate,q))
                    procs.append(p)
                    p.start()
        else:
            for i in pointname[l]:
                for t in valid_tsteps:  
                    p = mp.Process(target=plotOneData, args=(l,i,t,sdate,edate,q))
                    procs.append(p)
                    p.start()

    rtnval = []
    for p in procs:
        rtnval.append(q.get())
    for p in procs:
        p.join()

    return rtnval

def useMP(pointname):
    if is_Windows:
        rtnval = useMP_Windows(pointname)
    else:
        rtnval = useMP_Mac(pointname)

    return rtnval

def getPointname():
    conn = get_DBconn()

    pointname = {}
    pointname['sas'] = pd.read_sql(f'''
        select [PointName] 
        from [dbo].[RA_TargetWL] 
        where [newTarget] is not null and PointName not in ('BUD-14fl','BUD-21fl','WRW-s')
        order by PointName
    ''',conn)['PointName'].to_list()
    pointname['ufas'] = pd.read_sql(f'''
        select [PointName] from [dbo].[OROP_UFASwells]
        order by PointName
    ''',conn)['PointName'].to_list()
    pointname['pmp'] = pd.read_sql(f'''
        SELECT distinct SCADAName from (
            select [SCADAName],avg(WeeklyPumpage) Pumpage
            FROM [dbo].[RA_WeeklyPumpage] 
            ---WHERE OROP_WFCode IN ('CBR','COS','CYB','CYC','EDW','MRB','NWH','S21','SPC','STK')
            WHERE OROP_WFCode IN ('CBR','COS','CYB','CYC','EDW','MRB')
            group by SCADAName
        ) A WHERE Pumpage>0 
        order by SCADAName
    ''',conn)['SCADAName'].to_list()
    pointname['str'] = ['HILLS R AT MORRIS BRIDGE','ANCLOTE R NR ELFERS','PITHLA R NR NEW PT RICHEY ']
    pointname['spr'] = ['Sulphur Springs']
    pointname['ddn1'] = getDDN1cells(pointname['sas'],0.5)

    conn.close()
    return pointname

def regexFilter(strlist, pat):
    """Filters a list of strings based on a regex pattern."""
    import re
    rtnval = [s for s in strlist if re.search(pat, s)]

    return rtnval

def parse_args(args):
    parser = argparse.ArgumentParser(description='Plot hydrographs using data from Recovery Analysis period.')
    parser.add_argument('datatype', action='store', nargs='+', 
        help="Data type code ([pmp|sas|ufas|str|spr|ddn1])")
    parser.add_argument('pointname', action='store', nargs='+', 
        help="Name of data location as PointName (pass empty string for '-a' option)")
    parser.add_argument('--timestep', action='store', dest='timestep', default='Weekly,MFL',
        help="Data time interval ([Daily|Weekly|MFL] MFL option only available for streamflow data)")
    parser.add_argument('--start_date', action='store', dest='sdate', default='10/01/2007',
        help="PEST base runname to plot hydrograph (PEST runname, e.g. 'bp_036')")
    parser.add_argument('--end_date', action='store', dest='edate', default='09/30/2023',
        help='PEST runname to compare hydrograph, default to "none"')
    parser.add_argument('-p', action='store_true', dest='need_print', default=False,
        help='Create imagge file from plotting.')
    parser.add_argument('-a', action='store_true', dest='do_all', default=False,
        help='Plot all data locations using multiprocessing. Apply to a specific datatype if specified')
    return parser.parse_args(args)

if __name__ == '__main__':
    is_Windows = os.name=='nt'
    if is_Windows:
        proj_dir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    else:
        proj_dir = os.path.dirname(os.path.realpath(__file__))
    d_shape = os.path.join(proj_dir,'Shapefiles')

    pointname_default = getPointname()
    
    args = parse_args(sys.argv[1:])
    sdate = args.sdate
    edate = args.edate
    arg_timestep = list(args.timestep.split(','))
    datatype = list(args.datatype[0].split(','))
    locpat = list(args.pointname[0].split(','))
    if len(locpat)<len(datatype):
        locpat += [locpat[len(locpat)-1] for i in range(len(locpat),len(datatype))]
    pointname = {}
    for i in range(0,len(datatype)):
        if locpat[i]=='':
            locpat[i] = '.+'
        if datatype[i]=='ddn1':
            # expect dictionry of list by OROP SAS wellnames
            ptnames = pointname_default[datatype[i]].keys()
            ptnames = regexFilter(ptnames,locpat[i])
            pointname[datatype[i]] = {k:pointname_default[datatype[i]][k] for k in ptnames}
        else:
            pointname[datatype[i]] = regexFilter(pointname_default[datatype[i]],locpat[i])

    from datetime import datetime
    start_time = datetime.now()

    # multiprocessing
    if args.do_all:
        # process data on site at a time
        rtnval = useMP(pointname)
    else:
        rtnval = []
        for l in datatype:
            valid_tsteps = getValidTimestep(l)
            if l=='ddn1':
                for i in pointname[l].keys():
                    rtnval += [plotOneData(l,{i:pointname[l][i]},t,sdate,edate) for t in valid_tsteps]
            else:
                for i in pointname[l]:
                    rtnval += [plotOneData(l,i,t,sdate,edate) for t in valid_tsteps]

    # plotOneData(conn,'pmp',pointname['pmp'],'Daily',sdate,edate)
    # plotOneData(conn,'pmp',pointname['pmp'],'Weekly',sdate,edate)

    etime = datetime.now()-start_time
    print(f'Elasped time: {etime}')
    plt.show()

    exit()