import pyodbc
import pandas as pd
import os
import sys
import glob2
import numpy as np
import datetime
import matplotlib.pyplot as plt
import argparse


def sql_mnlysprflow(id,atdb_base,atdb_comp,sdate,edate):
    # Monthly Springflow
    if atdb_comp=='none':
        comp_select = ''
        comp_table = ''
    else:
        comp_select = r'   ,(AVG(D.ROVOL)*43560.0)/86400.0 AS comp_val '
        comp_table = f'''
    LEFT JOIN {atdb_comp}.dbo.ReachHistory AS D 
    ON Z.Date=D.Date AND Z.ReachID=D.ReachID
'''
    sql = f'''
    SELECT C.MonthStart Date
        ,AVG(ObservedIntervalMean) AS obs_val
        ,(AVG(Z.ROVOL)*43560.0)/86400.0 AS calib_val
        ,(AVG(A.ROVOL)*43560.0)/86400.0 AS base_val
    {comp_select}
    FROM (SELECT Date,MonthStart FROM INTBCalendar WHERE Date BETWEEN '{sdate}' AND '{edate}') AS C
    LEFT JOIN INTB_401C_Output.dbo.ReachHistory Z ON Z.Date=C.Date
    LEFT JOIN {atdb_base}.dbo.ReachHistory A
        ON Z.Date=A.Date AND Z.ReachID=A.ReachID
    {comp_table}
    INNER JOIN (SELECT * FROM Spring WHERE SpringId={id}) AS B ON Z.ReachID=B.ReachID
    LEFT JOIN (
        select LocationID,cast(IntervalStartDate as Date) Date, ObservedIntervalMean
        from ObservedDataIntervalStats
        where DataTypeCode=1 and IntervalTypeCode=1
    ) OS on OS.LocationID=B.SpringId and OS.Date=C.MonthStart
    GROUP BY C.MonthStart
    ORDER BY C.MonthStart
'''
    sitename = f'SELECT name FROM Spring WHERE SpringId={id}'
    return sql,sitename
    

def sql_wklysprflow(id,atdb_base,atdb_comp,sdate,edate):
    # Weekly Springflow
    if atdb_comp=='none':
        comp_select = '';
        comp_table = '';
    else:
        comp_select = r'   ,(AVG(D.ROVOL)*43560.0)/86400.0 AS comp_val '
        comp_table = f'''
    LEFT JOIN {atdb_comp}.dbo.ReachHistory D
        ON Z.Date=D.Date AND Z.ReachID=D.ReachID
'''
    sql = f'''
    SELECT C.WeekStart Date
        ,AVG(ObservedIntervalMean) AS obs_val
        ,(AVG(Z.ROVOL)*43560.0)/86400.0 AS calib_val
        ,(AVG(A.ROVOL)*43560.0)/86400.0 AS base_val
    {comp_select}
    FROM (SELECT Date,WeekStart FROM INTBCalendar WHERE Date BETWEEN '{sdate}' AND '{edate}') AS C
    LEFT JOIN INTB_401C_Output.dbo.ReachHistory Z ON Z.Date=C.Date
    LEFT JOIN {atdb_base}.dbo.ReachHistory A
        ON Z.Date=A.Date AND Z.ReachID=A.ReachID
    {comp_table}
    INNER JOIN (SELECT * FROM Spring WHERE SpringId={id}) AS B ON Z.ReachID=B.ReachID
    LEFT JOIN (
        select LocationID,cast(IntervalStartDate as Date) Date, ObservedIntervalMean
        from ObservedDataIntervalStats
        where DataTypeCode=1 and IntervalTypeCode=2
    ) OS on OS.LocationID=B.SpringId and OS.Date=C.WeekStart
    GROUP BY C.WeekStart
    ORDER BY C.WeekStart
'''
    sitename = f'SELECT name FROM Spring WHERE SpringId={id}'
    return sql,sitename


def sql_mnlystrflow(id,atdb_base,atdb_comp,sdate,edate):
    # Monthly Streamflow
    if atdb_comp=='none':
        base_select1 = ''
        comp_select = ''
        comp_table = ''
    else:
        base_select1 = r'       , SUM((D.ROVOL*43560.0)/86400.0 * B.ScaleFactor) Rate_CFS1 '
        comp_select = r'   , CASE WHEN AVG(A.Rate_CFS1)<0.1 THEN 0.1 ELSE AVG(A.Rate_CFS1) END comp_val '
        comp_table = f'''
    LEFT JOIN {atdb_comp}.dbo.ReachHistory D
        ON Z.Date=D.Date AND Z.ReachID=D.ReachID
'''
    sql = f'''
    SELECT A.MonthStart Date
        , CASE WHEN AVG(ObservedIntervalMean)<0.1 THEN 0.1 ELSE AVG(ObservedIntervalMean) END obs_val
        , CASE WHEN AVG(A.Calib_CFS)<0.1 THEN 0.1 ELSE AVG(A.Calib_CFS) END calib_val
        , CASE WHEN AVG(A.Rate_CFS)<0.1 THEN 0.1 ELSE AVG(A.Rate_CFS) END base_val
    {comp_select}
    FROM (
        SELECT C.Date,MIN(C.MonthStart) MonthStart
            , AVG(ObservedIntervalMean) ObservedIntervalMean
            , SUM((Z.ROVOL*43560.0)/86400.0 * B.ScaleFactor) Calib_CFS
            , SUM((A.ROVOL*43560.0)/86400.0 * B.ScaleFactor) Rate_CFS
    {base_select1}
        FROM (SELECT Date,MonthStart FROM INTBCalendar WHERE Date BETWEEN '{sdate}' AND '{edate}') AS C
        LEFT JOIN INTB_401C_Output.dbo.ReachHistory Z ON C.Date=Z.Date
        INNER JOIN (SELECT ReachID,ScaleFactor,FlowStationId FROM ReachFlowStation WHERE FlowStationId={id}) B
            ON Z.ReachID=B.ReachID
        LEFT JOIN {atdb_base}.dbo.ReachHistory A
            ON Z.Date=A.Date AND Z.ReachID=A.ReachID
    {comp_table}
        LEFT JOIN (
            select LocationID,cast(IntervalStartDate as Date) Date, ObservedIntervalMean
            from ObservedDataIntervalStats
            where DataTypeCode=2 and IntervalTypeCode=1
        ) OS on OS.LocationID=B.FlowStationId and OS.Date=C.Date
        GROUP BY C.Date
    ) A
    GROUP BY A.MonthStart
    ORDER BY A.MonthStart
'''
    sitename = f'SELECT StationName name FROM FlowStation WHERE FlowStationID={id}'
    return sql,sitename


def sql_wklystrflow(id,atdb_base,atdb_comp,sdate,edate):
    # Weekly Streamflow
    if atdb_comp=='none':
        base_select1 = ''
        comp_select = ''
        comp_table = ''
    else:
        base_select1 = r'       , SUM((D.ROVOL*43560.0)/86400.0 * B.ScaleFactor) Rate_CFS1 '
        comp_select = r'   , CASE WHEN AVG(A.Rate_CFS1)<0.1 THEN 0.1 ELSE AVG(A.Rate_CFS1) END comp_val '
        comp_table = f'''
    LEFT JOIN {atdb_comp}.dbo.ReachHistory D
        ON Z.Date=D.Date AND Z.ReachID=D.ReachID
'''
    sql = f'''
    SELECT A.WeekStart Date
        , CASE WHEN AVG(ObservedIntervalMean)<0.1 THEN 0.1 ELSE AVG(ObservedIntervalMean) END obs_val
        , CASE WHEN AVG(A.Calib_CFS)<0.1 THEN 0.1 ELSE AVG(A.Calib_CFS) END calib_val
        , CASE WHEN AVG(A.Rate_CFS)<0.1 THEN 0.1 ELSE AVG(A.Rate_CFS) END base_val
    {comp_select}
    FROM (
        SELECT C.Date,MIN(C.WeekStart) WeekStart
            , POWER(10,AVG(ObservedIntervalMean)) ObservedIntervalMean
            , SUM((Z.ROVOL*43560.0)/86400.0 * B.ScaleFactor) Calib_CFS
            , SUM((A.ROVOL*43560.0)/86400.0 * B.ScaleFactor) Rate_CFS
    {base_select1}
        FROM (SELECT Date,WeekStart FROM INTBCalendar WHERE Date BETWEEN '{sdate}' AND '{edate}') AS C
        LEFT JOIN INTB_401C_Output.dbo.ReachHistory Z ON C.Date=Z.Date
        INNER JOIN (SELECT ReachID,ScaleFactor,FlowStationId FROM ReachFlowStation WHERE FlowStationId={id}) B
            ON Z.ReachID=B.ReachID
        LEFT JOIN {atdb_base}.dbo.ReachHistory A
            ON Z.Date=A.Date AND Z.ReachID=A.ReachID
    {comp_table}
        LEFT JOIN (
            select LocationID,cast(IntervalStartDate as Date) Date, ObservedIntervalMean
            from ObservedDataIntervalStats
            where DataTypeCode=2 and IntervalTypeCode=2
        ) OS on OS.LocationID=B.FlowStationId and OS.Date=C.Date
        GROUP BY C.Date
    ) A
    GROUP BY A.WeekStart
    ORDER BY A.WeekStart
'''
    sitename = f'SELECT StationName name FROM FlowStation WHERE FlowStationID={id}'
    return sql,sitename


def sql_mnlygwhead(id,atdb_base,atdb_comp,sdate,edate):
    # Monthly Groundwater Head
    if atdb_comp=='none':
        comp_select = ''
        comp_table = ''
    else:
        comp_select = r'   , AVG(CASE WHEN D.Head=-9999 THEN NULL ELSE D.Head+OW.HeadShift END) comp_val '
        comp_table = f'''
    LEFT JOIN {atdb_comp}.dbo.HeadHistory D
        ON Z.Date=D.Date AND Z.CellID=D.CellID AND Z.LayerNumber=D.LayerNumber
'''
    sql = f'''
    SELECT C.MonthStart Date
        , AVG(ObservedIntervalMean) obs_val
        , AVG(CASE WHEN Z.Head=-9999 THEN NULL ELSE Z.Head+OW.HeadShift END) calib_val
        , AVG(CASE WHEN A.Head=-9999 THEN NULL ELSE A.Head+OW.HeadShift END) base_val
    {comp_select}
    FROM (SELECT Date,MonthStart FROM INTBCalendar WHERE Date BETWEEN '{sdate}' AND '{edate}') AS C
    LEFT JOIN INTB_401C_Output.dbo.HeadHistory Z ON C.Date=Z.Date
    RIGHT JOIN (
        SELECT A.LayerNumber,A.CellID,A.ObservedWellID
            ,CASE A.LayerNumber WHEN 1 THEN A.LandElevation-C.Topo ELSE 0 END HeadShift
        FROM ObservedWell A
        INNER JOIN Cell C ON A.CellID=C.CellID
        WHERE ObservedWellID={id}
    ) OW ON Z.LayerNumber=OW.LayerNumber AND Z.CellID=OW.CellID
    LEFT JOIN {atdb_base}.dbo.HeadHistory A
        ON Z.Date=A.Date AND Z.CellID=A.CellID AND Z.LayerNumber=A.LayerNumber
    {comp_table}
    LEFT JOIN (
        select LocationID,cast(IntervalStartDate as Date) Date, ObservedIntervalMean
        from ObservedDataIntervalStats
        where DataTypeCode=3 and IntervalTypeCode=1
    ) OS on OS.LocationID=OW.ObservedWellID and OS.Date=C.MonthStart
    GROUP BY C.MonthStart
    ORDER BY C.MonthStart
'''
    sitename = f'SELECT name FROM ObservedWell WHERE ObservedWellID={id}'
    return sql,sitename


def sql_wklygwhead(id,atdb_base,atdb_comp,sdate,edate):
    # Weekly Groundwater Head
    if atdb_comp=='none':
        comp_select = ''
        comp_table = ''
    else:
        comp_select = r'   , AVG(CASE WHEN D.Head=-9999 THEN NULL ELSE D.Head+OW.HeadShift END) comp_val '
        comp_table = f'''
    LEFT JOIN {atdb_comp}.dbo.HeadHistory D
        ON Z.Date=D.Date AND Z.CellID=D.CellID AND Z.LayerNumber=D.LayerNumber
'''
    sql = f'''
    SELECT CAST(C.WeekStart as DateTime) Date
        , AVG (ObservedIntervalMean) obs_val
        , AVG(CASE WHEN Z.Head=-9999 THEN NULL ELSE Z.Head+OW.HeadShift END) calib_val
        , AVG(CASE WHEN A.Head=-9999 THEN NULL ELSE A.Head+OW.HeadShift END) base_val
    {comp_select}
    FROM (SELECT Date,WeekStart FROM INTBCalendar WHERE Date BETWEEN '{sdate}' AND '{edate}') AS C
    LEFT JOIN INTB_401C_Output.dbo.HeadHistory Z ON C.Date=Z.Date
    RIGHT JOIN (
        SELECT A.LayerNumber,A.CellID,A.ObservedWellID
            ,CASE A.LayerNumber WHEN 1 THEN A.LandElevation-C.Topo ELSE 0 END HeadShift
        FROM ObservedWell A
        INNER JOIN Cell C ON A.CellID=C.CellID
        WHERE ObservedWellID={id}
    ) OW ON Z.LayerNumber=OW.LayerNumber AND Z.CellID=OW.CellID
    LEFT JOIN {atdb_base}.dbo.HeadHistory A
        ON Z.Date=A.Date AND Z.CellID=A.CellID AND Z.LayerNumber=A.LayerNumber
    {comp_table}
    LEFT JOIN (
        select LocationID,cast(IntervalStartDate as Date) Date, ObservedIntervalMean
        from ObservedDataIntervalStats
        where DataTypeCode=3 and IntervalTypeCode=2
    ) OS on OS.LocationID=OW.ObservedWellID and OS.Date=C.WeekStart
    GROUP BY C.WeekStart
    ORDER BY C.WeekStart    
'''
    sitename = f'SELECT name FROM ObservedWell WHERE ObservedWellID={id}'
    return sql,sitename


def getOneData(q,d_baseout,target_code,base_runname,comp_runname,por,res_flag,sdate,edate):
    dv = '{SQL Server}'
    sv = 'vgridfs'
    db = 'INTB_403'
    d_csv = os.path.join(d_baseout, 'PEST_Run')
    conn = pyodbc.connect(
        f'DRIVER={dv};SERVER={sv};Database={db};Trusted_Connection=Yes',autocommit=True)

    # break out target code
    datatype,intervaltype = target_code.split('_')
    id = datatype[-4:]

    # get sql and sitename
    if (datatype[:3].lower()=='gwl'):
        if (intervaltype.lower()=='wkly'):
            sql,sitename = sql_wklygwhead(datatype[-4:],base_runname,comp_runname,sdate,edate)
            ylabel = 'Weekly Waterlevel, ft NGVD'
        else:
            sql,sitename = sql_mnlygwhead(datatype[-4:],base_runname,comp_runname,sdate,edate)
            ylabel = 'Monthlyly Waterlevel, ft NGVD'
    elif (datatype[:3].lower()=='spr'):
        if (intervaltype.lower()=='wkly'):
            sql,sitename = sql_wklysprflow(datatype[-4:],base_runname,comp_runname,sdate,edate)
            ylabel = 'Weekly Flow, cfs'
        else:
            sql,sitename = sql_mnlysprflow(datatype[-4:],base_runname,comp_runname,sdate,edate)
            ylabel = 'Monthly Flow, cfs'
    else:
        if (intervaltype.lower()=='wkly'):
            sql,sitename = sql_wklystrflow(datatype[-4:],base_runname,comp_runname,sdate,edate)
            ylabel = 'Weekly Flow, cfs'
        else:
            sql,sitename = sql_mnlystrflow(datatype[-4:],base_runname,comp_runname,sdate,edate)
            ylabel = 'Monthly Flow, cfs'

    sitename = pd.read_sql(sitename, conn).name[0]
    tmp_df = pd.read_sql(sql, conn)

    # create dataframe for plotting
    df_res = []
    if comp_runname=='none':
        df = pd.DataFrame(tmp_df[['base_val', 'calib_val', 'obs_val']].values,
            index=tmp_df['Date'], columns=[base_runname, 'calibrated', 'observed'])
        if res_flag:
            tmp_df['calib_res'] = tmp_df.calib_val - tmp_df.obs_val
            tmp_df['base_res']  = tmp_df.base_val  - tmp_df.obs_val
            df_res = pd.DataFrame(tmp_df[['base_res', 'calib_res']].values,
                index=tmp_df['Date'], columns=[base_runname, 'calibrated'])
    else:
        df = pd.DataFrame(tmp_df[['base_val', 'comp_val', 'calib_val', 'obs_val']].values,
            index=tmp_df['Date'], columns=[base_runname, comp_runname, 'calibrated', 'observed'])
        if res_flag:
            tmp_df['calib_res'] = tmp_df.calib_val - tmp_df.obs_val
            tmp_df['base_res']  = tmp_df.base_val  - tmp_df.obs_val
            tmp_df['comp_res']  = tmp_df.comp_val  - tmp_df.obs_val
            df_res = pd.DataFrame(tmp_df[['base_res', 'comp_res', 'calib_res']].values,
                index=tmp_df['Date'], columns=[base_runname, comp_runname, 'calibrated'])

    conn.close()

    fig = plotOne(res_flag,sitename, datatype, ylabel, df, df_res, target_code)
    q.put(fig)


def plotOne(res_flag,sitename,datatype,ylabel,df,df_res,target_code):
    if res_flag:
        fig, ((ax1),(ax2)) = plt.subplots(nrows=2, ncols=1, sharex=True, num=sitename, figsize=(9,6), 
            gridspec_kw={'height_ratios':[3,1]})

        # plot streamflow on log scale
        if datatype[:3].lower()=='str':
            li = df.plot(ax=ax1, kind='line', grid=True, title=f'{sitename} ({datatype[-4:]})', logy=True)
        else:
            li = df.plot(ax=ax1, kind='line', grid=True, title=f'{sitename} ({datatype[-4:]})')

        df_res.plot(ax=ax2, kind='line', grid=True)
        
        ax1.set_ylabel(ylabel)
        ax1.lines[-1].set_marker('.')

        ax2.set_ylabel('Residual')

        plt.xticks(rotation=0, ha='center')
        plt.tight_layout(1.0)
        plt.show(block=False)
    else:
        # plot streamflow on log scale
        if datatype[:3].lower()=='str':
            li = ax = df.plot(kind='line', grid=True, figsize=(9,6), title=f'{sitename} ({datatype[-4:]})', logy=True)
        else:
            li = ax = df.plot(kind='line', grid=True, figsize=(9,6), title=f'{sitename} ({datatype[-4:]})')
        ax.set_ylabel(ylabel)
        ax.lines[-1].set_marker('.')
        plt.xticks(rotation=0, ha='center')
        plt.tight_layout(1.0)
        plt.show(block=False)
        # plt.show()
    return plt.gcf()


def main(target_codes,base_runname,comp_runname,por,res_flag):
    import multiprocessing as mp
    if (comp_runname=='' or base_runname.lower()==comp_runname.lower()):
        comp_runname = 'none'

    # d_root = os.path.split(os.path.abspath(os.path.realpath(sys.argv[0])))[0]
    # d_root = d_root.replace(r'\\vgridfs.vgrid.local\f_drive',r'F:')
    d_root = r'F:\IHM\BEOPEST'
    ihm_scen = 'PEST_Run'
    d_baseout = glob2.glob(os.path.join(d_root, base_runname,'vgrid*'))[0]
    f_atdb_base = os.path.join(d_baseout, ihm_scen, f'{base_runname}_lastrun.mdf')
 
    if comp_runname!='none':
        d_compout = glob2.glob(os.path.join(d_root, comp_runname,'vgrid*'))[0]
        f_atdb_comp = os.path.join(d_compout, ihm_scen, f'{comp_runname}_lastrun.mdf')

    dv = '{SQL Server}'
    sv = 'vgridfs'
    db = 'INTB_403'
    d_csv = os.path.join(d_baseout, ihm_scen)
    conn = pyodbc.connect(
        f'DRIVER={dv};SERVER={sv};Database={db};Trusted_Connection=Yes',autocommit=True)
    cursor = conn.cursor()

    sdate = '01/01/1989'
    edate = '01/01/2008'
    if not por:
        f_dbin = glob2.glob(os.path.join(d_baseout,'INTB*_input.mdf'))[0]
        dbname = os.path.splitext(os.path.basename(f_dbin))[0]
        cursor.execute(f'''
		if not exists(select name from sys.databases where name='{dbname}')
		begin
			exec sp_attach_db '{dbname}','{f_dbin}'
		end
''')        
        scn_props = pd.read_sql(
            f"select * from {dbname}.dbo.Scenario where Name='{ihm_scen}'", conn).loc[0, :]
        sdate = scn_props.IHMBinaryFileArchiveStartDate
        edate = scn_props.IHMBinaryFileArchiveEndDate
        if scn_props.SimulationEndDate < scn_props.IHMBinaryFileArchiveEndDate:
            edate = scn_props.SimulationEndDate
        sdate = (datetime.datetime.strptime(sdate,r'%Y-%m-%d %H:%M:%S')).strftime(r'%m/%d/%Y')
        edate = (datetime.datetime.strptime(edate,r'%Y-%m-%d %H:%M:%S')).strftime(r'%m/%d/%Y')
        cursor.execute(f"exec sp_detach_db '{dbname}'")
    
    # attach base runname database
    cursor.execute(f'''
		if not exists(select name from sys.databases where name='{base_runname}')
		begin
			exec sp_attach_db '{base_runname}','{f_atdb_base}'
		end
''')
    if comp_runname!='none':
        cursor.execute(f'''
		if not exists(select name from sys.databases where name='{comp_runname}')
		begin
			exec sp_attach_db '{comp_runname}','{f_atdb_comp}'
		end
''')

    # process data on site at a time
    mp.set_executable(os.path.join(sys.exec_prefix, 'python.exe'))
    q = mp.Queue()
    procs = []
    rtnval = []
    for x in target_codes:
        p = mp.Process(target=getOneData, 
            args=(q,d_baseout,x,base_runname,comp_runname,por,res_flag,sdate,edate))
        procs.append(p)
        p.start()
    for p in procs:
        rtnval.append(q.get())
    for p in procs:
        p.join()

    # [plotOne(res_flag,x[0],x[1],x[2],x[3],x[4],x[5]) for x in rtnval]
    plt.show()

    cursor.execute(f"exec sp_detach_db '{base_runname}'")
    if comp_runname!='none':
        cursor.execute(f"exec sp_detach_db '{comp_runname}'")
    conn.close()
    return rtnval


def parse_args(args):
    parser = argparse.ArgumentParser(description='Plot hydrographs using data from the specified PEST/INTB result.')
    parser.add_argument('target_code', action='store', nargs='+', 
        help="PEST target codes ([gwl|spr|str]{4-digit ID}_[wkly|mnly], e.g. 'gwl0946_wkly,gwl0946_mnly')")
    parser.add_argument('--base_runname', action='store', dest='base_runname', required=True,
        help="PEST base runname to plot hydrograph (PEST runname, e.g. 'bp_036')")
    parser.add_argument('--comp_runname', action='store', dest='comp_runname', default='none',
        help='PEST runname to compare hydrograph, default to "none"')
    parser.add_argument('-p', action='store_true', dest='por', default=False,
        help='Span over period of records')
    parser.add_argument('-r', action='store_true', dest='res_flag', default=False,
        help='Flag to include residual plot')
    return parser.parse_args(args)


if __name__ == '__main__':
    import time
    import multiprocessing as mp

    args = parse_args(sys.argv[1:])
    # args = parse_args(['str0002_wkly','str0002_mnly','spr0002_wkly','spr0002_mnly',
    #     '--base_runname','bp_049',
    #     '--comp_runname','bp_050','-r'])
    print(args.target_code)
    print(args.base_runname)
    main(args.target_code,args.base_runname,args.comp_runname,args.por,args.res_flag)

''' 
    stime = time.time()

    args = parse_args(sys.argv[1:])
    main(args.target_code,args.base_runname,args.comp_runname,args.por)

    args = parse_args(['str0002_wkly','bp_045'])
    main(args.target_code,args.base_runname,args.comp_runname,args.por)
    print(r'Elasped time: %.2f sec' % (time.time()-stime))

    args = parse_args(['str0002_wkly','bp_045','-cbp_032'])
    main(args.target_code,args.base_runname,args.comp_runname,args.por)
    print(r'Elasped time: %.2f sec' % (time.time()-stime))

    args = parse_args(['str0002_mnly','bp_045'])
    main(args.target_code,args.base_runname,args.comp_runname,args.por)
    print(r'Elasped time: %.2f sec' % (time.time()-stime))

    args = parse_args(['str0002_mnly','bp_045','-cbp_032'])
    main(args.target_code,args.base_runname,args.comp_runname,args.por)
    print(r'Elasped time: %.2f sec' % (time.time()-stime))
 '''