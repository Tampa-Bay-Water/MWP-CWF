import os
import sys
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
import multiprocessing as mp
from datetime import datetime
import yaml
import LoadData
from LoadData import ReadHead, ScreenTextColor

pd.options.mode.chained_assignment = None  # default='warn'

D_PROJECT = os.path.dirname(__file__)
D_MWP_CWF = os.path.dirname(os.path.dirname(D_PROJECT))
D_MWP_IHM = os.path.join(os.path.dirname(D_MWP_CWF),'MWP-IHM')

ROOT_DIR = os.path.dirname(os.path.realpath(__file__))
CONFIG_FILE = os.path.join(ROOT_DIR,'config.yml')
with open(CONFIG_FILE, 'r') as file:
    try:
        CONFIG = yaml.safe_load(file)
    except yaml.YAMLError as e:
        print(f"\033[91mError parsing YAML file: {e}\033[0m", file=sys.stderr)
        CONFIG = None

if ('debugpy' in sys.modules and sys.modules['debugpy'].__file__.find('/.vscode/extensions/') > -1):
    IS_DEBUGGING = True
else:
    IS_DEBUGGING = False

MAX_NUM_PROCESSES = CONFIG['general']['MAX_NUM_PROCESSES']
INTB_VERSION = CONFIG['general']['INTB_VERSION']
NEED_WEEKLY = CONFIG['general']['NEED_WEEKLY']

RUNID = CONFIG['scenario']['RUNID']
REALIZATIONS = eval(CONFIG['scenario']['REALIZATIONS'])
INTB_DATA_DIRNAME = CONFIG['scenario']['REALS_DIRNAME']
SUCCESSIVE_FAILS = CONFIG['scenario']['SUCCESSIVE_FAILS']

FIG_TITLE_FONTSIZE = CONFIG['plotting']['FIG_TITLE_FONTSIZE']
TITLE_FONTSIZE = CONFIG['plotting']['TITLE_FONTSIZE']
AX_LABEL_FONTSIZE = CONFIG['plotting']['AX_LABEL_FONTSIZE']

OROP_ACTIVEWELL = CONFIG['OROP_ACTIVEWELL']

if INTB_VERSION==1:
    # Period of Analysis INTB1
    POA = [CONFIG['INTB1']['POA_SDATE'],CONFIG['INTB1']['POA_EDATE']]
    SIMULATION_SDATE = CONFIG['INTB1']['SIMULATION_SDATE']
else:
    # Period of Analysis INTB1
    POA = [CONFIG['INTB2']['POA_SDATE'],CONFIG['INTB2']['POA_EDATE']]
    SIMULATION_SDATE = CONFIG['INTB2']['SIMULATION_SDATE']

# Screen Text Color
STC = ScreenTextColor
HEADER = STC.BK_FG+STC.BOLD
OKBLUE = STC.B_FG
OKCYAN = STC.C_FG
OKGREEN = STC.G_FG
OKYELLOW = STC.Y_FG
WARNING = STC.M_FG
FAIL = STC.R_FG
ENDC = STC.RESET
BOLD = STC.BOLD
UNDERLINE = STC.ULINE


def one_site_plot(df, real_id, name, datatype):
    fig, axes = plt.subplots(2, 1, figsize=(9.75, 13.5))
    fig.suptitle(f'RunID: {RUNID:04} RealizationID{real_id:04}'
        , fontsize=FIG_TITLE_FONTSIZE, fontweight='bold')
    g = sns.lineplot(ax=axes[0], x='Date', y='Waterlevel', data=df[0], hue='WL Stats',
        style='WL Stats', dashes=[(1,0),(1,0),(3,1)], palette='tab10')
    # g.lines[2].set_linestyle('--')
    ax2 = axes[0].twinx()
    g = ax2.stem(df[1].Date, df[1].Severity, linefmt='r-', label='Severity')
    plt.setp(g[0], markersize=4)
    [plt.setp(g[l], alpha=0.5) for l in range(3)]

    axes[0].set_xlabel("Date")
    axes[0].set_ylabel('Waterlevel, ft NGVD', c='blue')
    ax2.set_ylabel('Severity, ft', c='red')
    ax2.grid(False)
    axes[0].set_title(f'{df[0].columns[2]}: {name} ({datatype})', fontsize=TITLE_FONTSIZE)
    ylim = axes[0].get_ylim()
    ax2.set_ylim([0,(ylim[1]-ylim[0])*4])
    lines, labels = axes[0].get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    axes[0].legend(lines + lines2, labels + labels2, loc='upper left')

    nrow = len(df[2])
    df1 = pd.DataFrame(np.transpose(np.array([
        df[2]['Avg Severity'].sort_values().to_list(),
        [1-(x/nrow) for x in range(1, nrow + 1)]])),columns=['Avg Severity','Exceedence'])
    df2 = pd.DataFrame(np.transpose(np.array([
        df[2]['Max Severity'].sort_values().to_list(),
        [1-(x/nrow) for x in range(1, nrow + 1)]])),columns=['Max Severity','Exceedence'])
    tempDF = pd.merge(df1,df2, on='Exceedence')
    tempDF = pd.melt(tempDF, id_vars='Exceedence', var_name='Aggregation',
        value_vars=['Avg Severity', 'Max Severity'], value_name='Severity')
    tempDF.reindex()
    sns.lineplot(ax=axes[1], data=tempDF, x='Exceedence', y='Severity', hue="Aggregation")
    axes[1].set_xlabel("Exceedence")
    axes[1].set_ylabel("Severity, cfs")

    plt.tight_layout(pad=2.)
    # Show the plot
    return fig

def computeMetric(df,prefix):
    colname = f'{prefix}severity'
    col_pass = f'{prefix}pass'
    df[col_pass] = df[colname].rolling(window=SUCCESSIVE_FAILS).sum()<=0
    df[f'{colname}_avg'] = df[colname].rolling(window=SUCCESSIVE_FAILS).mean()
    df[f'{colname}_avg'] = df[f'{colname}_avg']*(1-df[col_pass].astype(int))
    df[f'{colname}_max'] = df[colname].rolling(window=SUCCESSIVE_FAILS).max()
    df[f'{colname}_max'] = df[f'{colname}_max']*(1-df[col_pass].astype(int))
    return df

def one_site_metric(df, statfns=['none','mean','median'], interval=[5,10], mfl=-1):
    for stat in statfns:
        match stat:
            case 'none':
                df['severity'] = mfl-df['Value']
                df.loc[df['severity']<0,'severity'] = 0.
                df = computeMetric(df,'')
            case 'mean':
                for i in interval:
                    prefix = f'avg{i:02}_'
                    df[f'{prefix}Value'] = df['Value'].rolling(window=52*i).mean()
                    colname = f'{prefix}severity'
                    df[colname] = mfl-df[f'{prefix}Value']
                    df.loc[df[colname]<0,colname] = 0.
                    df = computeMetric(df,prefix)
            case 'median':
                for i in interval:
                    prefix = f'med{i:02}_'
                    df[f'{prefix}Value'] = df['Value'].rolling(window=52*i).median()
                    colname = f'{prefix}severity'
                    df[colname] = mfl-df[f'{prefix}Value']
                    df.loc[df[colname]<0,colname] = 0.
                    df = computeMetric(df,prefix)

    # Windowing the result to POA
    date = np.logical_and(
        np.array(df['Date']>=POA[0]),np.array(df['Date']<=POA[1]))
    df = df[date]

    index_names = {
        'count': 'Total', 
        'mean': 'Average', 
        'std': 'Standard Deviation',
        'min': 'Minimum', 
        '5%': 'P5', 
        '10%': 'P10', 
        '25%': 'Q1', 
        '50%': 'Median', 
        '75%': 'Q3',
        'max': 'Maximum'}
    tempDF = df.drop(['PointID','Target','TargetType'], axis=1)
    summary = tempDF.describe([.05, .1, .25, .5, .75]).rename(index=index_names)
    return df,summary

def push2db(metricsDF, summaryDF, real_id, id, value_vars1, value_vars2,
        datatype='Waterlevel'):
    # populate database
    engine = LoadData.get_DBconn(True,'MWP_CWF_metric')
    conn = LoadData.get_DBconn(db='MWP_CWF_metric')
    with conn.cursor() as cur:
        cur.execute(f'''
            DELETE FROM dbo.Metric_TS  
            WHERE DataType='{datatype}' AND LocID={id} AND RealizationID = {real_id} AND RunID = RUNID;
            DELETE FROM dbo.Metric  
            WHERE DataType='{datatype}' AND LocID={id} AND RealizationID = {real_id} AND RunID = RUNID;
        ''')
    tempDF = pd.melt(metricsDF, id_vars='Date', var_name='metric',
        value_vars=value_vars1)
    tempDF['RunID'] = RUNID
    tempDF['RealizationID'] = real_id
    tempDF['DataType'] = datatype
    tempDF['LocID'] = id
    tempDF.to_sql('Metric_TS', engine, if_exists='append', index=False)

    tempDF = pd.melt(summaryDF.reset_index(), id_vars='index', var_name='metric',
        value_vars=value_vars2).rename(columns={'index':'Stats'})
    tempDF['RunID'] = RUNID
    tempDF['RealizationID'] = real_id
    tempDF['DataType'] = datatype
    tempDF['LocID'] = id
    tempDF.to_sql('Metric', engine, if_exists='append', index=False)
    conn.close()
    engine.dispose()
    return tempDF

def one_site(real_id, id, tempDF, rh):
    name = rh.owinfo[rh.owinfo['PointID']==id].PointName.values[0] # use modified owinfo
    # print(f'Push result to database for Well: {name} - Realization: {real_id}')
    idDF = tempDF[tempDF['PointID']==id]
    mfl = idDF.Target.values[0]
    metricsDF,summaryDF = one_site_metric(idDF, ['mean','median'], [8], mfl)
    metricsDF['Date'] = pd.to_datetime(metricsDF['Date'])
    summaryDF = push2db(metricsDF, summaryDF, real_id, id,
        value_vars1=[
            'Date', 'Value',
            'med08_Value', 'med08_pass', 'med08_severity', 'med08_severity_avg', 'med08_severity_max',
            'avg08_Value', 'avg08_pass', 'avg08_severity', 'avg08_severity_avg', 'avg08_severity_max',
        ],
        value_vars2=[
            'Value',
            'med08_Value', 'med08_severity','med08_severity_avg', 'med08_severity_max',
            'avg08_Value', 'avg08_severity','avg08_severity_avg', 'avg08_severity_max',
        ],
        datatype=idDF.TargetType.values[0]
    )

    # prepare dataframe for plotting
    plotWarehouse = os.path.join(D_PROJECT,'plotWarehouse')

    # plot using median
    df1 = pd.melt(metricsDF[['Date','Value','med08_Value','Target']].rename(
        columns={'Value':'Weekly Waterlevel', 'med08_Value':'8Yr-MovingMed'}),
        id_vars='Date', var_name='WL Stats',
        value_vars=['Weekly Waterlevel','8Yr-MovingMed','Target'], value_name='Waterlevel')
    df2 = metricsDF[['Date','med08_severity']].rename(columns={'med08_severity':'Severity'})
    df3 = metricsDF[['med08_severity_avg','med08_severity_max']].rename(
        columns={'med08_severity_avg':'Avg Severity','med08_severity_max':'Max Severity'})
    fig1 = one_site_plot([df1,df2,df3], real_id, name, idDF.TargetType.values[0])

    svfilePath = os.path.join(plotWarehouse,f'severity_{real_id:04}-8yrMed:{name}')
    # fig1.savefig(svfilePath, dpi=300, pad_inches=0.1, facecolor='auto', edgecolor='auto')
    fig1.savefig(svfilePath+'.pdf', orientation="portrait"
        , dpi=300, bbox_inches="tight", pad_inches=1, facecolor='auto', edgecolor='auto')
    if IS_DEBUGGING:
        # plt.show(block=True)
        plt.show(block=False)
    else:
        plt.show(block=False)
    fig1.clf()
    plt.close('all')

    # plot using mean
    df1 = pd.melt(metricsDF[['Date','Value','avg08_Value','Target']].rename(
        columns={'Value':'Weekly Waterlevel', 'avg08_Value':'8Yr-MovingAvg'}),
        id_vars='Date', var_name='WL Stats',
        value_vars=['Weekly Waterlevel','8Yr-MovingAvg','Target'], value_name='Waterlevel')
    df2 = metricsDF[['Date','avg08_severity']].rename(columns={'avg08_severity':'Severity'})
    df3 = metricsDF[['avg08_severity_avg','avg08_severity_max']].rename(
        columns={'avg08_severity_avg':'Avg Severity','avg08_severity_max':'Max Severity'})
    fig2 = one_site_plot([df1,df2,df3], real_id, name, idDF.TargetType.values[0])

    svfilePath = os.path.join(plotWarehouse,f'severity_{real_id:04}-8yrAvg:{name}')
    # fig2.savefig(svfilePath, dpi=300, pad_inches=0.1, facecolor='auto', edgecolor='auto')
    fig2.savefig(svfilePath+'.pdf', orientation="portrait"
        , dpi=300, bbox_inches="tight", pad_inches=1, facecolor='auto', edgecolor='auto')
    if IS_DEBUGGING:
        plt.show(block=True)
        # plt.show(block=False)
    else:
        plt.show(block=False)
    fig2.clf()
    plt.close('all')

    return summaryDF

def one_real_metric(real_id, wnames):
    # OROP Control Points:
    #   Limit to wells associated with Consolidated Wellfields
    #   Assess weekly pass/fail values for each well against the Target level, 
    #       a failed well is flagged if the waterlevel falled below the its Target 
    #       for four sussessive weeks has 
    #   OROP network failed if one half of the number of wells failed for a particular week
    #
    # Regulartoty & SWIMAL Wells:
    #   Evaluate network failure using the same proceduare as OROP CP network 

    run_dir = os.path.join(D_MWP_IHM,INTB_DATA_DIRNAME,f'intb_{real_id:04}')
    rh = ReadHead(run_dir)
    por = [SIMULATION_SDATE,POA[1]]
    df = rh.getHeadByWellnames(wnames, por, date_index=False, need_weekly=NEED_WEEKLY)
    cols = df.columns
    df = pd.melt(df, id_vars='Date', value_vars=cols[1:], var_name='PointName', value_name='Value')

    # Make waterlevel adjustment from regression correction
    conn = LoadData.get_DBconn()
    reg_df = pd.read_sql_query(f'''
        select LocID INTB_OWID,Slope,Intercept
        from MWP_CWF.dbo.INTB_Correction
        where INTB_Version={INTB_VERSION} and DataType='waterlevel'
        ''', conn)
    conn.close()
    reg_df = pd.merge(rh.owinfo, reg_df, on='INTB_OWID', how='inner')
    tempDF = pd.merge(df, reg_df ,on='PointName',how='inner')

    # Adjust with well surface elevation and cell topo
    tempDF['Value'] += tempDF['SurfEl2CellTopoOffset']

    # Error correction from regression: simulated to observed
    tempDF['Corrected'] = tempDF['Slope']*tempDF['Value'] + tempDF['Intercept']
    cols = ['Date', 'PointID', 'Target', 'TargetType', 'Corrected']
    df = tempDF[cols].rename(columns={'Corrected':'Value'})

    # Compute metric median over 8 years
    # tempDF = df[df['TargetType']=='OROP_CP']
    summaryDF = [one_site(real_id, id, df, rh) for id in df['PointID'].unique()]
    summaryDF = pd.concat(summaryDF, ignore_index=True)

    return summaryDF.to_dict()

def metric_assessment(metric_data):
    # summarize rtnval of metrics
    if isinstance(metric_data[0],dict):
        df = pd.concat([pd.DataFrame(d) for d in rtnval], ignore_index=True)
    else:
        # retrieve from database
        conn = LoadData.get_DBconn()
        df = pd.read_sql(f'''
            SELECT RealizationID,DataType,LocID,Metric,Stats,round([Value],3) Value
            FROM [MWP_CWF_metric].[dbo].[Metric]
            WHERE RunID={RUNID}
        ''', conn)
        conn.close()

    df_temp = df[df['Stats']=='P10']
    retained_cols = ['Value', 'RealizationID', 'DataType', 'LocID', 'Metric']
    df_med_pass = df_temp.loc[df_temp['Metric']=='med08_severity',retained_cols]
    df_med_pass['Value'] = (df_med_pass['Value']<=0.5).values.astype(float)
    df_med = df_med_pass.groupby(['RealizationID', 'DataType'])['Value'].mean()*100.
    df_med = pd.DataFrame(df_med)
    print(f"\n{df_med.rename(columns={'Value':'OROP_Network_pctPass'})}")
    df_med['Value'] = (df_med['Value']>=50.).values.astype(float)
    df_med = df_med.groupby(['DataType'])['Value'].mean()*100.
    df_med = pd.DataFrame(df_med).rename(columns={'Value':'Reliability'})
    print(f'\n{df_med}')
    # df_avg_pass = df_temp.loc[df_temp['metric']=='avg08_severity',retained_cols]
    # df_avg_pass['value'] = (df_avg_pass['value']<=0.5).values.astype(float)
    # df_avg = df_avg_pass.groupby(['RealizationID', 'DataType'])['value'].mean()*100.
    # df_avg.reset_index(inplace=True)
    return

def get_metric_MP1(real_id, wnames, q=None, sema=None):
    pid = os.getpid()
    print(f'{HEADER}Computing metric for realization: {real_id} on pid: {pid}{ENDC}')
    from time import sleep
    sleep(1)

    if q is not None:
        # plt.show(block=False)
        if q!=-1:
            print(f"{OKCYAN}Call Queue.Put type {type(real_id)} for process ID: {pid}{ENDC}")
            q.put(real_id)
            sema.release()

    if sema is not None:
        sema.release()

    return

def get_metric_MP(real_id, wnames, q=None, sema=None):
    pid = os.getpid()
    print(f'{HEADER}Computing metric for RunID(RealizationID): {RUNID}({real_id}) on pid: {pid}{ENDC}')
    r = one_real_metric(real_id, wnames)

    if q is not None:
        # plt.show(block=False)
        if q!=-1:
            pid = os.getpid()
            print(f"{OKCYAN}Call Queue.Put type {type(r)} for process ID: {pid}{ENDC}")
            q.put_nowait(real_id)
            sema.release()

    return

def useMP_Queue(wnames):
    # mp.set_start_method('fork')
    # create queue to get return value
    q = mp.Queue()
    sema = mp.Semaphore(MAX_NUM_PROCESSES)
    procs = []
    for real_id in REALIZATIONS:
        sema.acquire()
        p = mp.Process(target=get_metric_MP, args=(real_id, wnames, q, sema))
        # p = mp.Process(target=get_metric_MP1, args=(real_id, wnames, q, sema))
        procs.append(p)
        p.start()

    # wait for all procs to finish
    for p in procs:
        print(f"{OKGREEN}Call Process.join for process ID: {p.pid}{ENDC}")
        p.join()

    # get return value
    rtnval = []
    for p in procs:
        r = q.get_nowait()
        print(f"{OKYELLOW}Call Queue.Get type {type(r)} for process ID: {p.pid}{ENDC}")
        rtnval.append(r)

    return rtnval

def useMP_Pool(wnames):
    rtnval = []
    with mp.Pool(processes=5) as pool:
        for real_id in REALIZATIONS:
            p = pool.apply_async(get_metric_MP, args=(real_id, wnames))
            print(f"Return type from apply_async is '{type(p)}'.")
            r = p.get(timeout=60)
            print(f"Return type from pool.get is '{type(r)}'.")
            rtnval.append(r)

    return rtnval

def use_noMP(wnames):
    rtnval = []
    for real_id in REALIZATIONS[0:1]:
        r = one_real_metric(real_id, wnames)
        rtnval.append(r)
    return rtnval


if __name__ == '__main__':
    from image2pdf import merge_pdf
    sns.set_theme(style="darkgrid")
    plt.rcParams.update({'font.size': 8, 'savefig.dpi': 300})
    plotWarehouse = os.path.join(D_PROJECT,'plotWarehouse')
    conn = LoadData.get_DBconn()

    # List of Current OROP Wells (2023)
    orop_activewell = ','.join([f"'{s}'" for s in OROP_ACTIVEWELL])
    conn = LoadData.get_DBconn()
    wellDF = pd.read_sql(f'''
        SELECT PointName, TargetWL Target, 'orop_cp' Permit
        FROM [dbo].[RA_TargetWL]
        WHERE PointName in ({orop_activewell})
        UNION
        SELECT PointName, AvgMin Target, 'regulatory' Permit
        FROM [dbo].[RA_RegWellPermit]
        UNION
        SELECT PointName, MinAvg Target, 'swimal' Permit
        FROM [dbo].[swimalWL]
        WHERE PointName NOT IN ('EW-2S-Deep')
        ORDER BY Permit,PointName        
    ''', conn)

    owinfo = pd.read_sql(LoadData.owinfo_sql, conn)
    conn.close()
    wnames = wellDF.PointName.to_list()

    sortedDF = owinfo.sort_values(by=['TargetType','WFCode','PointName'])[['PointName']]
    # merge_pdf(D_PROJECT,sortedDF)

    def delete_plotWarehouse():
        if os.path.exists(plotWarehouse) and os.path.isdir(plotWarehouse):
            for f in os.listdir(plotWarehouse):
                try:
                    os.remove(os.path.join(plotWarehouse,f))
                except OSError as err:
                    print(err)
        else:
            os.mkdir(plotWarehouse)

    if not IS_DEBUGGING:
        delete_plotWarehouse()

    # Perform metric calculation for Waterlevel
    start_time = datetime.now()

    # use_mp = use_noMP | useMP_Queue | useMP_Pool
    # rtnval = use_noMP(wnames)
    rtnval = useMP_Queue(wnames)
    # rtnval = useMP_Pool(wnames)

    etime = datetime.now()-start_time
    print(f'Elasped time: {etime}')

    metric_assessment(rtnval)

    # merge pdf files
    if not IS_DEBUGGING:
        merge_pdf(D_PROJECT,sortedDF)

    exit(0)