DROP TABLE IF EXISTS #ra_sdate
select cast('10/01/2007' as datetime) ra_sdate
    , cast('09/30/2019' as datetime) ra_edate
    , cast('09/30/2013' as datetime) ra1_edate
    , cast('09/30/2023' as datetime) rae_edate
into #ra_sdate;
/*
-- sql command 2
DROP TABLE IF EXISTS #r;
SELECT WeekStartDate, failed1, failed6, failed8
into #r
FROM (
    SELECT DISTINCT WeekStartDate
        , AVG(100.*CASE WHEN [OneYr_MVMED]-TargetWL<0 THEN 1 ELSE 0 END) OVER(PARTITION BY WeekStartDate) failed1
        , AVG(100.*CASE WHEN [SixYr_MVMED]-TargetWL<0 THEN 1 ELSE 0 END) OVER (PARTITION BY WeekStartDate) failed6
        , AVG(100.*CASE WHEN [EightYr_MVMED]-TargetWL<0 THEN 1 ELSE 0 END) OVER (PARTITION BY WeekStartDate) failed8
    FROM [dbo].[RA_TargetWL] A
        INNER JOIN [dbo].[RA_SAS_WeeklyWL_MVMED] B ON A.PointName=B.PointName
    WHERE A.newTARGET IS NOT NULL AND A.PointName<>'WRW-s'
) X;

-- Get TBW pumpage
-- sql command 3
SELECT PointID, PointName, OROP_WFCode, WeekStartDate, WeekNo, WeeklyPumpage, FiftytwoWeek_MAV
FROM RA_WeeklyPumpage
WHERE WeekStartDate>=(select ra_sdate from #ra_sdate)
ORDER BY PointID,WeekNo;

-- sql command 4
SELECT WeekStartDate, avg(WeekNo) WeekNo, sum(WeeklyPumpage) cwf_total, sum(FiftytwoWeek_MAV) cwf_mavg
FROM RA_WeeklyPumpage
WHERE OROP_WFCode in ('CBR','COS','CYB','CYC','EDW','MRB','NPC','NWH','S21','SPC','STK')
GROUP BY WeekStartDate
ORDER BY WeekNo;

-- sql command 5
SELECT PointID, PointName, OROP_WFCode, MonthStartDate, MonthNo, MonthlyPumpage, TwelveMonth_MAV
FROM RA_MonthlyPumpage
WHERE MonthStartDate>=(select ra_sdate from #ra_sdate)
ORDER BY PointID,MonthNo;

-- sql command 6
SELECT MonthStartDate, avg(MonthNo) MonthNo, sum(MonthlyPumpage) cwf_total, sum(TwelveMonth_MAV) cwf_mavg
FROM RA_MonthlyPumpage
WHERE OROP_WFCode in ('CBR','COS','CYB','CYC','EDW','MRB','NPC','NWH','S21','SPC','STK')
GROUP BY MonthStartDate
ORDER BY MonthNo;

-- sql command 7
SELECT A.PointName, C.SiteID, C.CompositeTimeseriesID, C.WithdrawalPointID
    , RA_AVG, RA_AVG1, RA_AVG2, RA_AVG3
FROM (
    SELECT PointName, RA_AVG, RA_AVG1, RA_AVG2, RA_AVG3
    FROM (
        SELECT PointName, Avg(WeeklyPumpage) PUMPAGE, 'RA_AVG' POR
        FROM RA_WeeklyPumpage
        WHERE WeekStartDate BETWEEN (select ra_sdate from #ra_sdate) AND (select ra_edate from #ra_sdate)
        GROUP BY PointName
    UNION
        SELECT PointName, Avg(WeeklyPumpage) PUMPAGE, 'RA_AVG1' POR
        FROM RA_WeeklyPumpage
        WHERE WeekStartDate BETWEEN (select ra_sdate from #ra_sdate) AND (select ra1_edate from #ra_sdate)
        GROUP BY PointName
    UNION
        SELECT PointName, Avg(WeeklyPumpage) PUMPAGE, 'RA_AVG2' POR
        FROM RA_WeeklyPumpage
        WHERE WeekStartDate  BETWEEN DATEADD(DAY,1,(select ra1_edate from #ra_sdate)) AND (select ra_edate from #ra_sdate)
        GROUP BY PointName
    UNION
        SELECT PointName, Avg(WeeklyPumpage) PUMPAGE, 'RA_AVG3' POR
        FROM RA_WeeklyPumpage
        WHERE WeekStartDate>(select ra_edate from #ra_sdate)
        GROUP BY PointName
    ) A
    PIVOT (AVG(PUMPAGE) FOR POR IN (RA_AVG,RA_AVG1,RA_AVG2,RA_AVG3)) P
) A
INNER JOIN (
    SELECT OP.PointID, PointName, OP.SCADAName, CompositeTimeseriesID, SiteID
    FROM OROP_Data2.dbo.ParameterData PD
    INNER JOIN OROP_Data2.dbo.OROPPoint OP ON OP.PointID = PD.PointID
    WHERE PD.ParameterID = 9
) B ON A.PointName=B.PointName
INNER JOIN OROP_Data2.dbo.INTB_ProductionWell C ON C.SiteID=B.SiteID AND CWF_OldWUP<>1
ORDER BY A.PointName;

-- sql command 8
SELECT *
FROM OROP_Data2.dbo.INTB_ProductionWell
WHERE CWF_OldWUP<>1
ORDER BY SiteID;

-- Site information table
-- sql command 9
SELECT OP.PointID, OP.PointName OROP_SASwell, S.WellfieldCode, PD.CompositeTimeseriesID, OP.SiteID
    , S.DDLatitude, S.DDLongitude
FROM OROP_Data2.dbo.ParameterData AS PD
INNER JOIN OROP_Data2.dbo.OROPPoint AS OP ON OP.PointID = PD.PointID
INNER JOIN OROP_Data2.dbo.Site AS S ON S.SiteID = OP.SiteID
WHERE (PD.ParameterID = 21);

-- SAS water level
-- sql command 10
SELECT PointName, MIN(WeekStartDate) StartPOR
FROM RA_SAS_WeeklyWL
WHERE WeeklyWaterlevel IS NOT NULL
GROUP BY PointName;

-- Get OROP Target Waterlevels
-- sql command 11
SELECT PointName, TargetWL, oldTarget, newTarget
FROM RA_TargetWL
ORDER BY PointName;

-- sql command 12
DROP TABLE IF EXISTS #RA_TargetDeviation
SELECT A.PointID, A.PointName, WFCode, WeekStartDate
    , WeeklyWaterlevel, WeeklyWaterlevel-TargetWL Deviation
    , FiftytwoWeek_MAV, FiftytwoWeek_MAV-TargetWL Deviation_MAVG
INTO #RA_TargetDeviation
FROM RA_SAS_WeeklyWL A
INNER JOIN RA_TargetWL B ON A.PointName=B.PointName
ORDER BY PointName,WeekStartDate;

-- sql command 13
SELECT PointID, PointName, WFCode, WeekStartDate, WeeklyWaterlevel, Deviation, Deviation_MAVG
FROM #RA_TargetDeviation
WHERE WeekStartDate>=(select ra_sdate from #ra_sdate)
ORDER BY PointName,WeekStartDate;

-- sql command 14
SELECT PointID, PointName, WFCode, WeekStartDate, WeeklyWaterlevel, Deviation, Deviation_MAVG
FROM #RA_TargetDeviation
WHERE WeekStartDate>=(select ra_sdate from #ra_sdate) AND WeeklyWaterlevel IS NOT NULL
ORDER BY PointName,WeekStartDate;

-- sql command 15
SELECT *
FROM RA_SAS_WeeklyWL_MVMED
WHERE WeekStartDate>(select ra_sdate from #ra_sdate)
ORDER BY PointName,WeekStartDate;

-- sql command 16
SELECT *
FROM dbo.RA_SAS_WeeklyWL
ORDER BY PointName,WeekStartDate;
/*
-- sql command 16
DROP TABLE IF EXISTS #r
SELECT WeekStartDate, failed1, failed6, failed8
into #r
FROM (
    SELECT DISTINCT WeekStartDate
        , AVG(100.*CASE WHEN [OneYr_MVMED]-TargetWL<0 THEN 1 ELSE 0 END) OVER(PARTITION BY WeekStartDate) failed1
        , AVG(100.*CASE WHEN [SixYr_MVMED]-TargetWL<0 THEN 1 ELSE 0 END) OVER (PARTITION BY WeekStartDate) failed6
        , AVG(100.*CASE WHEN [EightYr_MVMED]-TargetWL<0 THEN 1 ELSE 0 END) OVER (PARTITION BY WeekStartDate) failed8
    FROM [dbo].[RA_TargetWL] A
        INNER JOIN [dbo].[RA_SAS_WeeklyWL_MVMED] B ON A.PointName=B.PointName
    WHERE A.newTARGET IS NOT NULL AND A.PointName<>'WRW-s'
) X;
*/
-- sql command 17
SELECT DISTINCT POR
    , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY failed1) OVER (Partition by POR) PercFail1
    , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY failed6) OVER (Partition by POR) PercFail6
    , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY failed8) OVER (Partition by POR) PercFail8
FROM (
    SELECT WeekStartDate, failed1, failed6, failed8
        , CASE WHEN WeekStartDate<'10/01/2013' THEN 'First6_RA_POR' ELSE 'Last6_RA_POR' END POR
    FROM #r
    UNION
    SELECT WeekStartDate, failed1, failed6, failed8, 'RA_POR' POR
    FROM #r
    --ORDER BY WeekStartDate
) X;

-- sql command 18
DROP TABLE IF EXISTS #t;
SELECT B.PointName, WeekStartDate
    --, CASE WHEN [SixYr_MVMED]-TargetWL<0 THEN 1 ELSE 0 END failed
    , CASE WHEN OneYr_MVMED-TargetWL<0 THEN 1 ELSE 0 END failed
    , row_number() OVER (partition by B.PointName order by WeekStartDate) rowid
    , OneYr_MVMED-TargetWL deviation
into #t
FROM [dbo].[RA_TargetWL] A
INNER JOIN [dbo].[RA_SAS_WeeklyWL_MVMED] B ON A.PointName=B.PointName
WHERE A.newTARGET IS NOT NULL AND A.PointName<>'WRW-s'
ORDER by B.PointName,WeekStartDate;

UPDATE #t set failed=3 -- start failed event
WHERE rowid=1 AND failed>0;

UPDATE #t set failed=4 -- end failed event
WHERE rowid=(SELECT max(rowid) FROM #t) AND failed>0;

UPDATE #t SET failed=failed+T.CODE -- START failed event
FROM (
SELECT t1.PointName PN,t1.WeekStartDate WSD
    , CASE WHEN t1.failed>0 AND t2.failed=0 THEN 2 ELSE NULL END CODE
FROM #t t1
INNER JOIN #t t2 ON t1.PointName=t2.PointName AND t1.WeekStartDate=t2.WeekStartDate+7
) T
WHERE PointName=T.PN AND WeekStartDate=T.WSD
    AND T.CODE IS NOT NULL
;
UPDATE #t SET failed=failed+T.CODE -- END failed event
FROM (
SELECT t1.PointName PN, t1.WeekStartDate WSD
    , CASE WHEN t1.failed>0 AND t2.failed=0 THEN 4 ELSE NULL END CODE
    FROM #t t1
        INNER JOIN #t t2 ON t1.PointName=t2.PointName AND t1.WeekStartDate=t2.WeekStartDate-7
) T
WHERE PointName=T.PN AND WeekStartDate=T.WSD
    AND T.CODE IS NOT NULL;
;
-- sql command 19
SELECT * FROM #t ORDER BY POINTNAME,WEEKSTARTDATE;

-- sql command 20
DROP TABLE IF EXISTS #d
SELECT T1.PointName WellName,T1.EVNUM,T1.rowid rowid_start,T2.rowid rowid_end
    , T1.WeekStartDate STARTDATE,T2.WeekStartDate ENDDATE,T2.rowid-T1.rowid+1 DURAT
    , CAST(NULL AS REAL) AVG_DEV, CAST(NULL AS REAL) MIN_DEV, CAST(NULL AS REAL) MED_DEV
into #d
FROM (
SELECT PointName, WeekStartDate, failed, rowid
    , row_number() OVER (PARTITION BY PointName,2&FAILED ORDER BY WeekStartDate) EVNUM
FROM #t) T1
INNER JOIN (
SELECT PointName, WeekStartDate, failed, rowid
    , row_number() OVER (PARTITION BY PointName,4&FAILED ORDER BY WeekStartDate) EVNUM
FROM #t
) T2 ON T1.PointName=T2.PointName AND T1.EVNUM=T2.EVNUM
WHERE T1.failed>2 AND T2.failed>2 AND T2.rowid<>1 AND T2.rowid>=T1.rowid
ORDER BY WellName, T1.EVNUM

UPDATE #d
SET AVG_DEV=avgdev,MIN_DEV=A.mindev,MED_DEV=meddev
FROM (
    SELECT WellName PointName, EVNUM eno , (
        SELECT avg(deviation)
        FROM #t
        WHERE rowid BETWEEN d.rowid_start AND d.rowid_end AND PointName=WellName
    ) avgdev ,(
        SELECT min(deviation)
        FROM #t
        WHERE rowid BETWEEN d.rowid_start AND d.rowid_end AND PointName=WellName
    ) mindev , (
        SELECT DISTINCT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY deviation) OVER ()
        FROM #t
        WHERE rowid BETWEEN d.rowid_start AND d.rowid_end AND PointName=WellName
    ) meddev
    FROM #d d
) A
WHERE WellName=PointName AND EVNUM=eno;

-- sql command 21
SELECT * FROM #d ORDER BY WellName,EVNUM;

-- sql command 22
DROP TABLE IF EXISTS #r
DROP TABLE IF EXISTS #t
DROP TABLE IF EXISTS #d;

-- sql command 23
SELECT * 
FROM [dbo].[DailyFlow]
ORDER BY [FlowStationID],[DATE];

-- sql command 24
SELECT * 
FROM FlowStats_MFL
WHERE stats_name LIKE 'Five%' OR stats_name LIKE 'Ten%'
ORDER BY EndDate,BlockNum,stats_name;

-- sql command 25
SELECT *
FROM MinimumFlowTable
ORDER BY FlowStationID,BlockNum,[Type],Tier;

-- sql command 26
select PointName,TSTAMP,DailyWaterlevel [Value]
from dbo.RA_SAS_DailyWL;

-- sql command 27
SELECT * FROM dbo.RA_RegWellPermit;

-- sql command 28
SELECT PointName,WFCode,TSTAMP,WeekNo,MonthNo,DailyWaterlevel
FROM dbo.RA_UFAS_DailyWL
ORDER BY PointName,TSTAMP;

-- sql command 29
SELECT PointName,WFCode,WeekStartDate,WeekNo,WeeklyWaterlevel,FiftytwoWeek_MAV,SixYear_MAV,EightYr_MAV
FROM dbo.RA_UFAS_WeeklyWL
ORDER BY PointName,WeekStartDate;
*/