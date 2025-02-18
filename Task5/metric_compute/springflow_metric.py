import os
import sys
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
import sqlalchemy as sa
from datetime import datetime
import yaml
import LoadData
from LoadData import GetFlow

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
SCENARIO_NAME = CONFIG['scenario']['SCENARIO_NAME']
REALIZATIONS = eval(CONFIG['scenario']['REALIZATIONS'])
INTB_DATA_DIRNAME = CONFIG['scenario']['REALS_DIRNAME']
SUCCESSIVE_FAILS = CONFIG['scenario']['SUCCESSIVE_FAILS']

CRYSTAL_SPRING_COMPLEX_ID = 11
CRYSTAL_SPRING_COMPLEX_NM = 'Crystal Springs Complex'


def one_site_plot(df, name):
    fig, axes = plt.subplots(2, 1, figsize=(9.75, 13.5))
    sns.lineplot(x='Date', y='Value', data=df, marker=None, ax=axes[0])
    ax2 = axes[0].twinx()
    g = ax2.stem(df.Date, df.severity, linefmt='r-')
    plt.setp(g[0], markersize=4)
    axes[0].set_xlabel("Date")
    axes[0].set_ylabel('Adjusted Springflow, cfs', c='blue')
    ax2.set_ylabel('Severity, cfs', c='red')
    axes[0].set_title(name)
    ax2.set_ylim(axes[0].get_ylim())

    nrow = len(df)
    df1 = pd.DataFrame(np.transpose(np.array([
        df['severity_avg'].sort_values().to_list(),
        [1-(x/nrow) for x in range(1, nrow + 1)]])),columns=['severity_avg','exceedence'])
    df2 = pd.DataFrame(np.transpose(np.array([
        df['severity_max'].sort_values().to_list(),
        [1-(x/nrow) for x in range(1, nrow + 1)]])),columns=['severity_max','exceedence'])
    tempDF = pd.merge(df1,df2, on='exceedence')
    tempDF = pd.melt(tempDF, id_vars='exceedence',
        value_vars=['severity_avg', 'severity_max'], var_name='aggregation')
    tempDF.reindex()
    sns.lineplot(data=tempDF, x='exceedence', y='value', hue="aggregation", ax=axes[1])
    axes[1].set_xlabel("Exceedence")
    axes[1].set_ylabel("Severity, cfs")

    plt.tight_layout()
    # Show the plot
    return fig

def one_site_metric(df, statfns=['none','mean','median'], interval=[5,10], mfl=-1):
    for stat in statfns:
        match stat:
            case 'none':
                df['pass'] = (df['Value']>=mfl).astype(int)
                df['successive_pass'] = df['pass'].rolling(window=SUCCESSIVE_FAILS).sum()>0
                df['severity'] = mfl-df['Value']
                df.loc[df['severity']<0,'severity'] = 0.
                df['severity_avg'] = df['severity'].rolling(window=SUCCESSIVE_FAILS).mean()
                df['severity_avg'] = df['severity_avg']*df['successive_pass'].astype(int)
                df['severity_max'] = df['severity'].rolling(window=SUCCESSIVE_FAILS).max()
                df['severity_max'] = df['severity_max']*df['successive_pass'].astype(int)
            case 'mean':
                for i in interval:
                    df[f'avg{i:02}'] = df['Value'].rolling(window=52*i).mean()
                    col_pass = f'avg{i:02}_pass'
                    df[col_pass] = (df[f'avg{i:02}']>=mfl).astype(int)
                    df[col_pass] = df[col_pass].rolling(window=SUCCESSIVE_FAILS).sum()>0
                    colname = f'avg{i:02}_severity'
                    df[colname] = mfl-df[f'avg{i:02}']
                    df.loc[df[colname]<0,colname] = 0.
                    df[f'{colname}_avg'] = df[colname].rolling(window=SUCCESSIVE_FAILS).mean()
                    df[f'{colname}_avg'] = df[f'{colname}_avg']*df[col_pass].astype(int)
                    df[f'{colname}_max'] = df[colname].rolling(window=SUCCESSIVE_FAILS).max()
                    df[f'{colname}_max'] = df[f'{colname}_max']*df[col_pass].astype(int)                
                    df.loc[df[colname]==0,colname] = np.nan
            case 'median':
                for i in interval:
                    df[f'med{i:02}'] = df['Value'].rolling(window=52*i).median()
                    col_pass = f'med{i:02}_pass'
                    df[col_pass] = (df[f'med{i:02}']>=mfl).astype(int)
                    df[col_pass] = df[col_pass].rolling(window=SUCCESSIVE_FAILS).sum()>0
                    colname = f'med{i:02}_severity'
                    df[colname] = mfl-df[f'med{i:02}']
                    df.loc[df[colname]<0,colname] = 0.
                    df[f'{colname}_avg'] = df[colname].rolling(window=SUCCESSIVE_FAILS).mean()
                    df[f'{colname}_avg'] = df[f'{colname}_avg']*df[col_pass].astype(int)
                    df[f'{colname}_max'] = df[colname].rolling(window=SUCCESSIVE_FAILS).max()
                    df[f'{colname}_max'] = df[f'{colname}_max']*df[col_pass].astype(int)                
                    df.loc[df[colname]==0,colname] = np.nan
    index_names = {
        'count': 'Total', 
        'mean': 'Average', 
        'std': 'Standard Deviation',
        'min': 'Minimum', 
        '25%': 'Q1', 
        '50%': 'Median', 
        '75%': 'Q3',
        'max': 'Maximum'}
    summary = df.describe().rename(index=index_names)
    return df,summary

def push2db(metricsDF, summaryDF, id, value_vars1, value_vars2,
        datatype='spring'):
    # populate database
    engine = LoadData.get_DBconn(True,'MWP_CWF_metric')
    conn = LoadData.get_DBconn(db='MWP_CWF_metric')
    with conn.cursor() as cur:
        cur.execute(f'''
            DELETE FROM dbo.Metric_TS  
            WHERE DataType='{datatype}' AND LocID={id};
            DELETE FROM dbo.Metric  
            WHERE DataType='{datatype}' AND LocID={id};
        ''')
    tempDF = pd.melt(metricsDF, id_vars='Date', var_name='metric',
        value_vars=value_vars1)
    tempDF['DataType'] = datatype
    tempDF['LocID'] = id
    tempDF.to_sql('Metric_TS', engine, if_exists='append', index=False)

    tempDF = pd.melt(summaryDF.reset_index(), id_vars='index', var_name='metric',
        value_vars=value_vars2).rename(columns={'index':'Stats'})
    tempDF['DataType'] = datatype
    tempDF['LocID'] = id
    tempDF.to_sql('Metric', engine, if_exists='append', index=False)
    conn.close()
    engine.dispose()
    return

def one_real_metric(real_id):
    # Spring MFL
    # Crystal Springs complex :
    #   The recommended minimum flow is 46 cfs based on a 5-year running mean/median. 
    #   Springflow will be determined from the difference between the above and below gages (2 & 74)
    # Sulphur Spring (ID = 3):
    #   The proposed minimum flow for Sulphur Springs is 18 cfs.
    #   This minimum flow may be reduced to 10 cfs during low tide stages in the lower Hillsborough River 
    #   if it does not result in salinity incursions from the Lower Hillsborough River into the upper spring run. 

    run_dir = os.path.join(D_MWP_IHM,INTB_DATA_DIRNAME,f'intb_{real_id:04}')
    gf = GetFlow(run_dir,INTB_VERSION,is_river=False)
    gf.SpringInfo

    # Sulphur Springs
    SpringID = 3
    mfl = 18.
    df = gf.getSpringflow_Vector([SpringID],need_weekly=True,date_index=False)

    # Make springflow adjustment from regression correction
    conn = gf.get_DBconn()
    reg_df = pd.read_sql_query(f'''
        select 'ID_'+RIGHT(FORMAT(CAST(LocID as FLOAT)/100.,'N2'),2) SprID,Slope,Intercept
        from MWP_CWF.dbo.INTB_Correction
        where INTB_Version={INTB_VERSION} and DataType='spring'
        ''', conn)
    conn.close()
    reg_df = pd.merge(df,reg_df,on='SprID',how='left')
    reg_df['Corrected'] = reg_df['Slope']*reg_df['Value']+reg_df['Intercept']
    df = reg_df[['Date','SprID','Corrected']].rename(columns={'Corrected':'Value'})
    df.loc[df['Value']<0,'Value'] = 0

    # Compute metric
    metricsDF,summaryDF = one_site_metric(df, ['none'], mfl=mfl)
    push2db(metricsDF, summaryDF, SpringID,
        value_vars1=[
            'Date', 'Value', 'pass', 'successive_pass', 'severity',
            'severity_avg', 'severity_max'],
        value_vars2=[
            'Value', 'pass', 'severity', 'severity_avg', 'severity_max'
        ],
    )
    # name = gf.SpringInfo.loc[gf.SpringInfo.SpringID==3,'Description'].values[0]
    # fig = one_site_plot(metricsDF, name)
    # svfilePath = os.path.join(plotWarehouse,f'severity_{real_id:04}-{name}')
    # fig.savefig(svfilePath, dpi=300, pad_inches=0.1, facecolor='auto', edgecolor='auto')
    # # plt.savefig(svfilePath+'.pdf', orientation="portrait"
    # #     , dpi=300, bbox_inches="tight", pad_inches=1, facecolor='auto', edgecolor='auto')
    # fig.clear()
    # # plt.close()

    # Crystall Springs complex
    mfl = 46
    gf = GetFlow(run_dir,INTB_VERSION,is_river=True)
    df1 = gf.getStreamflow_Table([2],need_weekly=True,date_index=False)
    df2 = gf.getStreamflow_Table([LoadData.HILLS_R_BL_Crystal_ID],need_weekly=True,date_index=False)
    df = pd.melt(pd.merge(df1, df2, on='Date'), id_vars='Date', value_name='Value',
        value_vars=['ID_02',f'ID_{LoadData.HILLS_R_BL_Crystal_ID:02}'], var_name='FlowID')
    # Make streamflow adjustment from regression correction
    conn = gf.get_DBconn()
    reg_df = pd.read_sql_query(f'''
        select 'ID_'+RIGHT(FORMAT(CAST(LocID as FLOAT)/100.,'N2'),2) FlowID,Slope,Intercept
        from MWP_CWF.dbo.INTB_Correction
        where INTB_Version={INTB_VERSION} and DataType='river'
        ''', conn)
    conn.close()
    reg_df = pd.merge(df,reg_df,on='FlowID',how='left')
    reg_df['Corrected'] = reg_df['Slope']*reg_df['Value']+reg_df['Intercept']
    df = reg_df[['Date','FlowID','Corrected']].rename(columns={'Corrected':'Value'})
    df.loc[df['Value']<0,'Value'] = 0

    # Compute Springs Complex Flow = lower gage - upper gage
    # temp_id = f'ID_{CRYSTAL_SPRING_COMPLEX_ID:02}'
    df = df.pivot(index='Date', columns='FlowID', values='Value').reset_index()
    df['Value'] = df[f'ID_{LoadData.HILLS_R_BL_Crystal_ID:02}']-df['ID_02']

    # Compute metric
    metricsDF,summaryDF = one_site_metric(df[['Date','Value']], ['mean','median'], interval=[5], mfl=mfl)
    push2db(metricsDF, summaryDF, CRYSTAL_SPRING_COMPLEX_ID,
        value_vars1=[
            'Value', 'avg05', 'avg05_pass', 'avg05_severity',
            'avg05_severity_avg', 'avg05_severity_max', 'med05', 'med05_pass',
            'med05_severity', 'med05_severity_avg', 'med05_severity_max'
        ],
        value_vars2=[
            'Value', 'avg05', 'avg05_severity',
            'avg05_severity_avg', 'avg05_severity_max', 'med05',
            'med05_severity', 'med05_severity_avg', 'med05_severity_max'
        ],
    )

    name = CRYSTAL_SPRING_COMPLEX_NM
    fig = one_site_plot(metricsDF, name)
    svfilePath = os.path.join(plotWarehouse,f'severity_{real_id:04}-{name}')
    fig.savefig(svfilePath, dpi=300, pad_inches=0.1, facecolor='auto', edgecolor='auto')
    # plt.savefig(svfilePath+'.pdf', orientation="portrait"
    #     , dpi=300, bbox_inches="tight", pad_inches=1, facecolor='auto', edgecolor='auto')
    fig.clear()
    # plt.close()
    return

def get_metric_MP(real_id, q=None, sema=None):
    one_real_metric(real_id)
    return

def useMP_Queue():
    import multiprocessing as mp
    # create queue to get return value
    q = mp.Queue()
    sema = mp.Semaphore(MAX_NUM_PROCESSES)
    procs = []
    for real_id in REALIZATIONS:
        sema.acquire()
        p = mp.Process(target=get_metric_MP, args=(real_id, q, sema))
        procs.append(p)
        p.start()

    # get return value
    rtnval = []
    for p in procs:
        rtnval += q.get()

    # wait for all procs to finish
    for p in procs:
        p.join()
    return rtnval

def useMP_Pool():
    import multiprocessing as mp
    rtnval = []
    with mp.Pool(processes=5) as pool:
        for real_id in REALIZATIONS:
            p = pool.apply_async(get_metric_MP,args=(real_id))
            print(f"Return type from apply_async is '{type(p)}'.")
            r= p.get(timeout=60)
            print(f"Return type from get is '{type(r)}'.")
            rtnval += r

    return rtnval

def use_noMP():
    return get_metric_MP(REALIZATIONS[0])


if __name__ == '__main__':
    need_weekly = True
    sns.set_theme(style="darkgrid")
    plt.rcParams.update({'font.size': 8, 'savefig.dpi': 300})
    plotWarehouse = os.path.join(D_PROJECT,'plotWarehouse')

    # merge_pdf(proj_dir)
    # move_result()

    # Perform metric calculation for Springflow
    if IS_DEBUGGING:
        # use_mp = use_noMP | useMP_Queue | useMP_Pool
        use_mp = 'use_noMP '
    else:
        use_mp = 'useMP_Queue'
        if os.path.exists(plotWarehouse) and os.path.isdir(plotWarehouse):
            for f in os.listdir(plotWarehouse):
                try:
                    os.remove(os.path.join(plotWarehouse,f))
                except OSError as err:
                    print(err)
        else:
            os.mkdir(plotWarehouse)

    start_time = datetime.now()
    if use_mp=='useMP_Queue':
        rtnval = useMP_Queue()
    elif use_mp=='useMP_Pool':
        rtnval = useMP_Pool()
    else:
        rtnval = use_noMP()
        # mem_usage = memory_usage(use_noMP)

    etime = datetime.now()-start_time
    print(f'Elasped time: {etime}')
