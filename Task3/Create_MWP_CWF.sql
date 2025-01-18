/*
USE master;

IF DB_ID (N'MWP_CWF') IS NOT NULL
DROP DATABASE MWP_CWF;

CREATE DATABASE MWP_CWF
ON
( NAME = MWP_CWF,
    FILENAME = '/var/opt/mssql/MWP_CWF.mdf')
LOG ON
( NAME = MWP_CWF_log,
    FILENAME = '/var/opt/mssql/MWP_CWF_log.mdf'
);

USE MWP_CWF
DROP TABLE IF EXISTS FlowStation
CREATE TABLE FlowStation(
	[FlowStationID] [int] NOT NULL,
	[SiteNumber] [nvarchar](8) NOT NULL,
	[StationName] [nvarchar](50) NOT NULL,
	[Description] [nvarchar](255) NULL,
	[UseInCalibration] [bit] NOT NULL,
	[RegionID] [int] NULL,
	[Quality] [int] NULL,
	[PlotIndex] [int] NULL,
	[X] [float] NULL,
	[Y] [float] NULL,
	[Comment] [nvarchar](255) NULL
) ON [PRIMARY]

ALTER TABLE FlowStation ADD  CONSTRAINT [PK_FlowStation] PRIMARY KEY CLUSTERED 
(
	[FlowStationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

INSERT INTO FlowStation
SELECT * FROM IHM.[dbo].[FlowStation] ORDER BY FlowStationID

DROP TABLE IF EXISTS StreamflowTimeSeries
CREATE TABLE StreamflowTimeSeries(
	[FlowStationID] [int] NOT NULL,
	[SiteNumber] [nvarchar](50) NULL,
	[DATE] [datetime] NOT NULL,
	[Value] [float] NULL
) ON [PRIMARY]

ALTER TABLE StreamflowTimeSeries ADD  CONSTRAINT [PK_StreamflowTimeSeries] PRIMARY KEY CLUSTERED 
(
	[FlowStationID] ASC,
	[DATE] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

INSERT INTO StreamflowTimeSeries
SELECT * FROM IHM.[dbo].[StreamflowTimeSeries] ORDER BY FlowStationID,[DATE]

DROP TABLE IF EXISTS Spring
CREATE TABLE Spring(
	[SpringID] [int] NOT NULL,
	[Name] [nvarchar](50) NULL,
	[Description] [nvarchar](255) NULL,
	[ReachID] [int] NULL,
	[RegionID] [int] NULL,
	[Quality] [int] NULL,
	[PlotIndex] [int] NULL,
	[X] [float] NULL,
	[Y] [float] NULL,
	[Comment] [nvarchar](255) NULL
) ON [PRIMARY]

ALTER TABLE Spring ADD  CONSTRAINT [PK_Spring] PRIMARY KEY CLUSTERED 
(
	[SpringID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

INSERT INTO Spring
SELECT * FROM IHM.[dbo].[Spring] ORDER BY SpringID

DROP TABLE IF EXISTS SpringflowTimeSeries
CREATE TABLE SpringflowTimeSeries(
	[SpringID] [int] NOT NULL,
	[Name] [nvarchar](50) NULL,
	[Date] [datetime] NOT NULL,
	[Value] [float] NULL,
	[Estimated] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE SpringflowTimeSeries ADD  CONSTRAINT [PK_SpringflowTimeSeries] PRIMARY KEY CLUSTERED 
(
	[SpringID] ASC,
	[Date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

INSERT INTO SpringflowTimeSeries
SELECT * FROM IHM.[dbo].[SpringflowTimeSeries] ORDER BY SpringID,[DATE]
*/

/*
USE OROP_Data2
DECLARE @ra_startdate date = '10/01/2007'
DECLARE @ra_enddate date = '09/30/2023'
DECLARE @orop_origdate date = dateadd(d,7-DATEPART(dw,'1900-01-01'),'1900-01-01') -- First Saturday

DROP TABLE IF EXISTS MWP_CWF.[dbo].[RA_DailyPumpage];

CREATE TABLE MWP_CWF.[dbo].[RA_DailyPumpage]
(
    [PointID] [varchar](25) NOT NULL,
    [PointName] [varchar](50) NOT NULL,
    [SCADAName] [varchar](50) NULL,
    [OROP_WFCode] [nvarchar](3) NULL,
    [CompositeTimeseriesID] [int] NULL,
    [TSTAMP] [DateTime] NOT NULL,
    [WeekNo] [int] NOT NULL,
    [MonthNo] [int] NOT NULL,
    [DailyPumpage] [float] NULL
) ON [PRIMARY];;

ALTER TABLE MWP_CWF.[dbo].[RA_DailyPumpage] ADD  CONSTRAINT [PK_RA_DailyPumpage] PRIMARY KEY CLUSTERED 
(
	[PointID] ASC,
    [TSTAMP] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];

INSERT INTO MWP_CWF.[dbo].[RA_DailyPumpage]
SELECT Y.PointID, PointName, SCADAName, LEFT(PointName,3) OROP_WFCode
    , CompositeTimeseriesID, TSTAMP, WeekNo, MonthNo
    , CASE when TimeSeriesValue is NULL then 0 else TimeSeriesValue END DailyPumpage
FROM (
    SELECT PD.PointID, TimeSeriesDateTime, TimeSeriesValue
    FROM TimeSeries ts
        INNER JOIN ParameterData PD ON ts.ParameterDataID = PD.ParameterDataID
    WHERE PD.ParameterID = 9 AND TimeSeriesDateTime BETWEEN DATEADD(YY,-1,@ra_startdate) AND @ra_enddate 
    --ORDER BY PointName, TimeSeriesDateTime
) X
    RIGHT JOIN (
    SELECT PointID, PointName, SCADAName, CompositeTimeseriesID, TSTAMP, WeekNo, MonthNo
    FROM (
        SELECT OP.PointID, PointName, OP.SCADAName, CompositeTimeseriesID
        FROM ParameterData PD
            INNER JOIN OROPPoint OP ON OP.PointID = PD.PointID
        WHERE PD.ParameterID = 9
    ) A
    ,
        (
        SELECT TSTAMP
            , 1+floor(cast(DATEDIFF(d,@ra_startdate,TSTAMP) as real)/7.) WeekNo
            , (year(tstamp)-year(@ra_startdate))*12+month(tstamp)-9 MonthNo
        FROM TS.dbo.Daily(DATEADD(YY,-1,@ra_startdate),@ra_enddate)
    ) B
) Y ON X.PointID=Y.PointID AND X.TimeSeriesDateTime=Y.TSTAMP
ORDER BY Y.PointID,TSTAMP;
*/

ALTER TABLE MWP_CWF.[dbo].[RA_DailyPumpage] 
ADD [OneYear_MAV] float NULL
GO
;

UPDATE MWP_CWF.[dbo].[RA_DailyPumpage]
SET [OneYear_MAV] = A.[One-year MAV]
FROM (
    SELECT PointName [Name],TSTAMP [Date],
        AVG([DailyPumpage]) OVER(PARTITION BY PointID ORDER BY TSTAMP ROWS BETWEEN 364 PRECEDING AND 0 FOLLOWING) [One-Year MAV]
    FROM MWP_CWF.[dbo].[RA_DailyPumpage]
) A WHERE TSTAMP=[Date] and PointName=[Name]; 

DROP TABLE IF EXISTS MWP_CWF.[dbo].[RA_WeeklyPumpage];

CREATE TABLE MWP_CWF.[dbo].[RA_WeeklyPumpage]
(
    PointID [int] NOT NULL,
    PointName [varchar](25) NOT NULL,
    SCADAName [varchar](25) NULL,
    OROP_WFCode [nvarchar](3) NULL,
    WeekStartDate [DateTime] NOT NULL,
    WeekNo [int] NOT NULL,
    WeeklyPumpage [float] NULL,
    FiftytwoWeek_MAV [float] NULL
);

ALTER TABLE MWP_CWF.[dbo].[RA_WeeklyPumpage] ADD  CONSTRAINT [PK_RA_WeeklyPumpage] PRIMARY KEY CLUSTERED 
(
	[PointID] ASC,
    [WeekStartDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];

INSERT INTO MWP_CWF.[dbo].[RA_WeeklyPumpage]
SELECT OP.PointID, PointName, SCADAName, OROP_WFCode, WeekStartDate, WeekNo, WeeklyPumpage
    , AVG(WeeklyPumpage) OVER(ORDER BY A.PointID,WeekStartDate ROWS BETWEEN 51 PRECEDING AND 0 FOLLOWING) FiftytwoWeek_MAV
FROM (
    SELECT PointID, min(OROP_WFCode) OROP_WFCode, min(TSTAMP) WeekStartDate, WeekNo, avg(DailyPumpage) WeeklyPumpage
    FROM MWP_CWF.[dbo].[RA_DailyPumpage]
    GROUP BY PointID,WeekNo
) A
    INNER JOIN OROPPoint OP ON OP.PointID = A.PointID
ORDER BY A.PointID,WeekNo;

DROP TABLE IF EXISTS MWP_CWF.[dbo].[RA_MonthlyPumpage];

CREATE TABLE MWP_CWF.[dbo].[RA_MonthlyPumpage]
(
    PointID [int] NOT NULL,
    PointName [varchar](25) NOT NULL,
    SCADAName [varchar](25) NULL,
    OROP_WFCode [nvarchar](3) NULL,
    MonthStartDate [DateTime] NOT NULL,
    MonthNo [int] NOT NULL,
    MonthlyPumpage [float] NULL,
    TwelveMonth_MAV [float] NULL
);

ALTER TABLE MWP_CWF.[dbo].[RA_MonthlyPumpage] ADD  CONSTRAINT [PK_RA_MonthlyPumpage] PRIMARY KEY CLUSTERED 
(
	[PointID] ASC,
    [MonthStartDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];

INSERT INTO MWP_CWF.[dbo].[RA_MonthlyPumpage]
SELECT OP.PointID, PointName, SCADAName, OROP_WFCode, MonthStartDate, MonthNo, MonthlyPumpage
    , AVG(MonthlyPumpage) OVER(ORDER BY A.PointID,MonthStartDate ROWS BETWEEN 11 PRECEDING AND 0 FOLLOWING) TwelveMonth_MAV
FROM (
    SELECT PointID, min(OROP_WFCode) OROP_WFCode, min(TSTAMP) MonthStartDate, MonthNo, avg(DailyPumpage) MonthlyPumpage
    FROM MWP_CWF.[dbo].[RA_DailyPumpage]
    GROUP BY PointID,MonthNo
) A
    INNER JOIN OROPPoint OP ON OP.PointID = A.PointID
ORDER BY A.PointID,MonthNo;
/*
--- SAS Waterlevel
DROP TABLE IF EXISTS MWP_CWF.[dbo].[RA_SAS_DailyWL];

CREATE TABLE MWP_CWF.[dbo].[RA_SAS_DailyWL]
(
    PointID [int] NOT NULL,
    PointName [varchar](25) NOT NULL,
    WFCode [nvarchar](3) NULL,
    CompositeTimeseriesID [int] NULL,
    TSTAMP [DateTime] NOT NULL,
    WeekNo [int] NOT NULL,
    MonthNo [int] NOT NULL,
    DailyWaterlevel [float] NULL
);

ALTER TABLE MWP_CWF.[dbo].[RA_SAS_DailyWL] ADD  CONSTRAINT [PK_RA_SAS_DailyWL] PRIMARY KEY CLUSTERED 
(
	[PointID] ASC,
    [TSTAMP] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];

INSERT INTO MWP_CWF.[dbo].[RA_SAS_DailyWL]
SELECT Y.PointID, Y.PointName, Y.WellfieldCode AS WFCode, Y.CompositeTimeseriesID
    , Y.TSTAMP, Y.WeekNo, Y.MonthNo, X.TimeSeriesValue AS DailyWaterlevel
FROM (
    SELECT PD.PointID, TS.TimeSeriesDateTime, TS.TimeSeriesValue
    FROM dbo.TimeSeries AS TS
        INNER JOIN dbo.ParameterData AS PD ON TS.ParameterDataID = PD.ParameterDataID
    WHERE (PD.ParameterID = 21) AND (TS.TimeSeriesDateTime BETWEEN '09/27/1999' AND @ra_enddate)
) AS X
    RIGHT OUTER JOIN (
    SELECT A.PointID, A.PointName, A.WellfieldCode, A.CompositeTimeseriesID
        , B.TSTAMP, B.WeekNo, B.MonthNo
    FROM (
        SELECT OP.PointID, OP.PointName, S.WellfieldCode, PD.CompositeTimeseriesID
        FROM dbo.ParameterData AS PD
            INNER JOIN dbo.OROPPoint AS OP ON OP.PointID = PD.PointID
            INNER JOIN dbo.Site AS S ON S.SiteID = OP.SiteID
        WHERE (PD.ParameterID = 21)
    ) AS A 
    CROSS JOIN (
        SELECT TSTAMP
            , 1 + FLOOR(CAST(DATEDIFF(d, @ra_startdate, TSTAMP) AS real) / 7.) AS WeekNo
            , (YEAR(TSTAMP) - YEAR(@ra_startdate)) * 12 + MONTH(TSTAMP) - 9 AS MonthNo
        FROM TS.dbo.Daily('09/27/1999', @ra_enddate) AS Daily_1
    ) AS B                          
) AS Y ON X.PointID = Y.PointID AND X.TimeSeriesDateTime = Y.TSTAMP
ORDER BY Y.PointID,Y.TSTAMP;

DROP TABLE IF EXISTS MWP_CWF.[dbo].[RA_SAS_WeeklyWL];

CREATE TABLE MWP_CWF.[dbo].[RA_SAS_WeeklyWL]
(
    PointID [int] NOT NULL,
    PointName [varchar](25) NOT NULL,
    WFCode [nvarchar](3) NULL,
    WeekStartDate [DateTime] NOT NULL,
    WeekNo [int] NOT NULL,
    WeeklyWaterlevel [float] NULL,
    FiftytwoWeek_MAV [float] NULL,
    SixYear_MAV [float] NULL,
    EightYr_MAV [float] NULL
);

ALTER TABLE MWP_CWF.[dbo].[RA_SAS_WeeklyWL] ADD  CONSTRAINT [PK_RA_SAS_WeeklyWL] PRIMARY KEY CLUSTERED 
(
	[PointID] ASC,
    [WeekStartDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];

INSERT INTO MWP_CWF.[dbo].[RA_SAS_WeeklyWL]
SELECT OP.PointID, PointName, WFCode
    , WeekStartDate, WeekNo, WeeklyWaterlevel
    , AVG(WeeklyWaterlevel) OVER(order by A.PointID,WeekStartDate ROWS BETWEEN 51 PRECEDING AND 0 FOLLOWING) FiftytwoWeek_MAV
    , AVG(WeeklyWaterlevel) OVER(ORDER BY A.PointID,WeekStartDate ROWS BETWEEN 311 PRECEDING AND 0 FOLLOWING) SixYear_MAV
    , AVG(WeeklyWaterlevel) OVER(ORDER BY A.PointID,WeekStartDate ROWS BETWEEN 416 PRECEDING AND 0 FOLLOWING) EightYr_MAV
--, PERCENTILE_CONT(WeeklyWaterlevel) OVER(ORDER BY A.PointID,WeekStartDate ROWS BETWEEN 311 PRECEDING AND 0 FOLLOWING) SixYear_MMED
FROM (
    SELECT PointID, min(WFCode) WFCode
        , min(TSTAMP) WeekStartDate, WeekNo, avg(DailyWaterlevel) WeeklyWaterlevel
    FROM MWP_CWF.[dbo].[RA_SAS_DailyWL]
    GROUP BY PointID,WeekNo
) A
    INNER JOIN OROPPoint OP ON OP.PointID = A.PointID
ORDER BY PointID,WeekNo;

--- UFAS Waterlevel
DROP TABLE IF EXISTS MWP_CWF.[dbo].[RA_UFAS_DailyWL];

CREATE TABLE MWP_CWF.[dbo].[RA_UFAS_DailyWL]
(
    PointID [int] NOT NULL,
    PointName [varchar](25) NOT NULL,
    WFCode [nvarchar](3) NULL,
    CompositeTimeseriesID [int] NULL,
    TSTAMP [DateTime] NOT NULL,
    WeekNo [int] NOT NULL,
    MonthNo [int] NOT NULL,
    DailyWaterlevel [float] NULL
);

ALTER TABLE MWP_CWF.[dbo].[RA_UFAS_DailyWL] ADD  CONSTRAINT [PK_RA_UFAS_DailyWL] PRIMARY KEY CLUSTERED 
(
	[PointID] ASC,
    [TSTAMP] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];

INSERT INTO MWP_CWF.[dbo].[RA_UFAS_DailyWL]
SELECT Y.PointID, Y.PointName, Y.WellfieldCode AS WFCode, Y.CompositeTimeseriesID
    , Y.TSTAMP, Y.WeekNo, Y.MonthNo, X.TimeSeriesValue AS DailyWaterlevel
FROM (
    SELECT PD.PointID, TS.TimeSeriesDateTime, TS.TimeSeriesValue
    FROM dbo.TimeSeries AS TS
        INNER JOIN dbo.ParameterData AS PD ON TS.ParameterDataID = PD.ParameterDataID
    WHERE (PD.ParameterID = 22) AND (TS.TimeSeriesDateTime BETWEEN '09/27/1999' AND @ra_enddate)
) AS X
    RIGHT OUTER JOIN (
    SELECT A.PointID, A.PointName, A.WellfieldCode, A.CompositeTimeseriesID
        , B.TSTAMP, B.WeekNo, B.MonthNo
    FROM (
        SELECT OP.PointID, OP.PointName, S.WellfieldCode, PD.CompositeTimeseriesID
        FROM dbo.ParameterData AS PD
            INNER JOIN dbo.OROPPoint AS OP ON OP.PointID = PD.PointID
            INNER JOIN dbo.Site AS S ON S.SiteID = OP.SiteID
        WHERE (PD.ParameterID = 22)
    ) AS A 
    CROSS JOIN (
        SELECT TSTAMP
            , 1 + FLOOR(CAST(DATEDIFF(d, @ra_startdate, TSTAMP) AS real) / 7.) AS WeekNo
            , (YEAR(TSTAMP) - YEAR(@ra_startdate)) * 12 + MONTH(TSTAMP) - 9 AS MonthNo
        FROM TS.dbo.Daily('09/27/1999', @ra_enddate) AS Daily_1
    ) AS B                          
) AS Y ON X.PointID = Y.PointID AND X.TimeSeriesDateTime = Y.TSTAMP
ORDER BY Y.PointID,Y.TSTAMP;

DROP TABLE IF EXISTS MWP_CWF.[dbo].[RA_UFAS_WeeklyWL];

CREATE TABLE MWP_CWF.[dbo].[RA_UFAS_WeeklyWL]
(
    PointID [int] NOT NULL,
    PointName [varchar](25) NOT NULL,
    WFCode [nvarchar](3) NULL,
    WeekStartDate [DateTime] NOT NULL,
    WeekNo [int] NOT NULL,
    WeeklyWaterlevel [float] NULL,
    FiftytwoWeek_MAV [float] NULL,
    SixYear_MAV [float] NULL,
    EightYr_MAV [float] NULL
);

ALTER TABLE MWP_CWF.[dbo].[RA_UFAS_WeeklyWL] ADD  CONSTRAINT [PK_RA_UFAS_WeeklyWL] PRIMARY KEY CLUSTERED 
(
	[PointID] ASC,
    [WeekStartDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];

INSERT INTO MWP_CWF.[dbo].[RA_UFAS_WeeklyWL]
SELECT OP.PointID, PointName, WFCode
    , WeekStartDate, WeekNo, WeeklyWaterlevel
    , AVG(WeeklyWaterlevel) OVER(order by A.PointID,WeekStartDate ROWS BETWEEN 51 PRECEDING AND 0 FOLLOWING) FiftytwoWeek_MAV
    , AVG(WeeklyWaterlevel) OVER(ORDER BY A.PointID,WeekStartDate ROWS BETWEEN 311 PRECEDING AND 0 FOLLOWING) SixYear_MAV
    , AVG(WeeklyWaterlevel) OVER(ORDER BY A.PointID,WeekStartDate ROWS BETWEEN 416 PRECEDING AND 0 FOLLOWING) EightYr_MAV
--, PERCENTILE_CONT(WeeklyWaterlevel) OVER(ORDER BY A.PointID,WeekStartDate ROWS BETWEEN 311 PRECEDING AND 0 FOLLOWING) SixYear_MMED
FROM (
    SELECT PointID, min(WFCode) WFCode
        , min(TSTAMP) WeekStartDate, WeekNo, avg(DailyWaterlevel) WeeklyWaterlevel
    FROM MWP_CWF.[dbo].[RA_UFAS_DailyWL]
    GROUP BY PointID,WeekNo
) A
    INNER JOIN OROPPoint OP ON OP.PointID = A.PointID
ORDER BY PointID,WeekNo;

DROP TABLE IF EXISTS MWP_CWF.[dbo].[RA_TargetWL];

CREATE TABLE MWP_CWF.[dbo].[RA_TargetWL]
(
    PointName [varchar](25) NOT NULL,
    oldTarget [float] NULL,
    newTarget [float] NULL,
    TargetWL [float] NULL,
    Change [float] NULL
);

ALTER TABLE MWP_CWF.[dbo].[RA_TargetWL] ADD  CONSTRAINT [PK_RA_TargetWL] PRIMARY KEY CLUSTERED 
(
	[PointName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];

INSERT INTO MWP_CWF.[dbo].[RA_TargetWL]
SELECT
    CASE WHEN A.Point IS NULL THEN B.Point ELSE A.Point END PointName
    , A.sas_ht oldTarget, B.sas_ht newTarget
    , CASE WHEN B.Point IS NULL THEN A.sas_ht ELSE B.sas_ht END TargetWL
    , CASE WHEN B.sas_ht-A.sas_ht=0 THEN NULL ELSE B.sas_ht-A.sas_ht END Change
FROM GetSavedTargetWeight(DATE_BUCKET (week,1, @ra_startdate,@orop_origdate)) A
FULL OUTER JOIN
    GetSavedTargetWeight(DATE_BUCKET (week,1, @ra_enddate,@orop_origdate)) B ON A.Point=B.Point
ORDER BY PointName;

UPDATE MWP_CWF.[dbo].[RA_TargetWL]
SET newTarget=41.42, TargetWL=41.42,Change=-0.18
WHERE PointName='MB-537s';

DROP TABLE IF EXISTS MWP_CWF.[dbo].[RA_RegWellPermit];

CREATE TABLE MWP_CWF.[dbo].[RA_RegWellPermit]
(
    PointName [varchar](25) NOT NULL,
    Swing [float] NULL,
    AvgMin [float] NULL,
    err_slope [float] NULL,
    err_intercept [float] NULL
);

ALTER TABLE MWP_CWF.[dbo].[RA_RegWellPermit] ADD  CONSTRAINT [PK_RA_RegWellPermit] PRIMARY KEY CLUSTERED 
(
	[PointName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];

INSERT INTO MWP_CWF.[dbo].[RA_RegWellPermit]
SELECT PointName,swing,avgmin,err_slope,err_intercept 
FROM SystemReliability_V3.dbo.vw_sysrel_GetRegWellWLPermit
ORDER BY PointName;

-- Compute moving median for weekly SAS waterlevel during Recovery Analysis period
DROP TABLE IF EXISTS MWP_CWF.[dbo].[RA_SAS_WeeklyWL_MVMED];

CREATE TABLE MWP_CWF.[dbo].[RA_SAS_WeeklyWL_MVMED]
(
    PointName [varchar](25) NOT NULL,
    WeekNo [int] NOT NULL,
    WeekStartDate [DateTime] NOT NULL,
    OneYr_MVMED [float] NULL,
    SixYr_MVMED [float] NULL,
    EightYr_MVMED [float] NULL
);

ALTER TABLE MWP_CWF.[dbo].[RA_SAS_WeeklyWL_MVMED] ADD  CONSTRAINT [PK_RA_SAS_WeeklyWL_MVMED] PRIMARY KEY CLUSTERED 
(
	[PointName] ASC,
    [WeekStartDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];

DECLARE @r table(
    PointName Varchar(25),
    WkNo int,
    rstart1 int,
    rstart6 int,
    rstart8 int,
    rend int
)
INSERT INTO @r
SELECT PointName, WeekNo, rstart1, rstart6, rstart8, rend
FROM (
    SELECT WeekNo
        , row_number() OVER(ORDER BY WeekNo) - 51 rstart1
        , row_number() OVER(ORDER BY WeekNo) - 311 rstart6
        , row_number() OVER(ORDER BY WeekNo) - 415 rstart8
        , row_number() OVER(ORDER BY WeekNo) rend
    FROM (
        SELECT distinct WeekNo
        FROM MWP_CWF.[dbo].[RA_SAS_WeeklyWL]
    ) d
) a, (
    SELECT distinct PointName
    FROM MWP_CWF.[dbo].[RA_SAS_WeeklyWL]
) b
WHERE weekno>0
ORDER BY PointName,weekno

INSERT INTO MWP_CWF.[dbo].[RA_SAS_WeeklyWL_MVMED]
SELECT PointName, WeekNo, WeekStartDate, OneYr_MVMED, SixYr_MVMED, EightYr_MVMED
FROM (
    SELECT A.PointName, A.WkNo WeekNo, B.WeekStartDate, MVMED, MVMED_NAME
    FROM (
        SELECT DISTINCT r.PointName, r.WkNo
            , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY WeeklyWaterlevel) OVER(PARTITION BY r.PointName,r.WkNo) MVMED
            , 'OneYr_MVMED' mvmed_name
        FROM @r r
        LEFT JOIN (
            SELECT *, row_number() OVER(PARTITION by pointname ORDER BY weekno) RowNum
            FROM MWP_CWF.[dbo].[RA_SAS_WeeklyWL] 
        ) o ON o.RowNum BETWEEN r.rstart1 AND r.rend AND r.PointName=o.PointName
        UNION
        SELECT DISTINCT r.PointName, r.WkNo
            , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY WeeklyWaterlevel) OVER(PARTITION BY r.PointName,r.WkNo) MVMED
            , 'SixYr_MVMED' mvmed_name
        FROM @r r
        LEFT JOIN (
            SELECT *, row_number() OVER(PARTITION by pointname ORDER BY weekno) RowNum
            FROM MWP_CWF.[dbo].[RA_SAS_WeeklyWL] 
        ) o ON o.RowNum BETWEEN r.rstart6 AND r.rend AND r.PointName=o.PointName
        UNION
        SELECT DISTINCT r.PointName, r.WkNo
            , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY WeeklyWaterlevel) 
                OVER(PARTITION BY r.PointName,r.WkNo) MVMED
            , 'EightYr_MVMED' mvmed_name
        FROM @r r
        LEFT JOIN (
            SELECT *, row_number() OVER(PARTITION by pointname ORDER BY weekno) RowNum
            FROM MWP_CWF.[dbo].[RA_SAS_WeeklyWL] 
        ) o ON o.RowNum BETWEEN r.rstart8 AND r.rend AND r.PointName=o.PointName
    ) A
        INNER JOIN (
        SELECT DISTINCT PointName, WeekNo, WEEKSTARTDATE
        FROM MWP_CWF.[dbo].[RA_SAS_WeeklyWL]
        WHERE WeekNo>0
    ) B ON A.PointName=B.PointName AND A.WKNO=B.WeekNo
) X PIVOT (
    AVG(MVMED) FOR MVMED_NAME IN (OneYr_MVMED, SixYr_MVMED, EightYr_MVMED)
) P;

DROP TABLE IF EXISTS MWP_CWF.[dbo].[RA_UFAS_WeeklyWL_MVMED];

CREATE TABLE MWP_CWF.[dbo].[RA_UFAS_WeeklyWL_MVMED]
(
    PointName [varchar](25) NOT NULL,
    WeekNo [int] NOT NULL,
    WeekStartDate [DateTime] NOT NULL,
    OneYr_MVMED [float] NULL,
    SixYr_MVMED [float] NULL,
    EightYr_MVMED [float] NULL
);

ALTER TABLE MWP_CWF.[dbo].[RA_UFAS_WeeklyWL_MVMED] ADD  CONSTRAINT [PK_RA_UFAS_WeeklyWL_MVMED] PRIMARY KEY CLUSTERED 
(
	[PointName] ASC,
    [WeekStartDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];

DECLARE @r table(
    PointName Varchar(25),
    WkNo int,
    rstart1 int,
    rstart6 int,
    rstart8 int,
    rend int
)
INSERT INTO @r
SELECT PointName, WeekNo, rstart1, rstart6, rstart8, rend
FROM (
    SELECT WeekNo
        , row_number() OVER(ORDER BY WeekNo) - 51 rstart1
        , row_number() OVER(ORDER BY WeekNo) - 311 rstart6
        , row_number() OVER(ORDER BY WeekNo) - 415 rstart8
        , row_number() OVER(ORDER BY WeekNo) rend
    FROM (
        SELECT distinct WeekNo
        FROM MWP_CWF.[dbo].[RA_UFAS_WeeklyWL]
    ) d
) a, (
    SELECT distinct PointName
    FROM MWP_CWF.[dbo].[RA_UFAS_WeeklyWL]
) b
WHERE weekno>0
ORDER BY PointName,weekno;

DROP TABLE IF EXISTS #r
SELECT A.PointName, A.WkNo WeekNo, MVMED, MVMED_NAME into #r
FROM (
    SELECT DISTINCT r.PointName, r.WkNo
        , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY WeeklyWaterlevel) OVER(PARTITION BY r.PointName,r.WkNo) MVMED
        , 'OneYr_MVMED' mvmed_name
    FROM @r r
    LEFT JOIN (
        SELECT *, row_number() OVER(PARTITION by pointname ORDER BY weekno) RowNum
        FROM MWP_CWF.[dbo].[RA_UFAS_WeeklyWL] 
    ) o ON o.RowNum BETWEEN r.rstart1 AND r.rend AND r.PointName=o.PointName
    UNION
    SELECT DISTINCT r.PointName, r.WkNo
        , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY WeeklyWaterlevel) OVER(PARTITION BY r.PointName,r.WkNo) MVMED
        , 'SixYr_MVMED' mvmed_name
    FROM @r r
    LEFT JOIN (
        SELECT *, row_number() OVER(PARTITION by pointname ORDER BY weekno) RowNum
        FROM MWP_CWF.[dbo].[RA_UFAS_WeeklyWL] 
    ) o ON o.RowNum BETWEEN r.rstart6 AND r.rend AND r.PointName=o.PointName
    UNION
    SELECT DISTINCT r.PointName, r.WkNo
        , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY WeeklyWaterlevel) 
            OVER(PARTITION BY r.PointName,r.WkNo) MVMED
        , 'EightYr_MVMED' mvmed_name
    FROM @r r
    LEFT JOIN (
        SELECT *, row_number() OVER(PARTITION by pointname ORDER BY weekno) RowNum
        FROM MWP_CWF.[dbo].[RA_UFAS_WeeklyWL] 
    ) o ON o.RowNum BETWEEN r.rstart8 AND r.rend AND r.PointName=o.PointName
) A

INSERT INTO MWP_CWF.[dbo].[RA_UFAS_WeeklyWL_MVMED]
SELECT PointName, WeekNo, WeekStartDate, OneYr_MVMED, SixYr_MVMED, EightYr_MVMED
FROM (
    SELECT A.PointName, A.WeekNo, B.WeekStartDate, A.MVMED, A.MVMED_NAME
    FROM #r A
    INNER JOIN (
        SELECT DISTINCT PointName, WeekNo, WEEKSTARTDATE
        FROM MWP_CWF.[dbo].[RA_UFAS_WeeklyWL]
        WHERE WeekNo>0
    ) B ON A.PointName=B.PointName AND A.WeekNo=B.WeekNo
) X PIVOT (
    AVG(MVMED) FOR MVMED_NAME IN (OneYr_MVMED, SixYr_MVMED, EightYr_MVMED)
) P;
*/

/* 
--- Build flow table and compute statistics
--- Block flow regimes based on MFL documents for specific River
USE MWP_CWF

DROP TABLE IF EXISTS DailyFlow
CREATE TABLE DailyFlow
(
    FlowStationID INT NOT NULL,
    SiteNumber NVARCHAR(8) NULL,
    [DATE] DATETIME NOT NULL,
    [Value] FLOAT NULL,
    [Year] INT NOT NULL,
    [Block] FLOAT NULL,
    OneYrMvAvg FLOAT NULL,
    FiveYrMvAvg FLOAT NULL,
    TenYrMvAvg FLOAT NULL,
    OneYrMvMed float NULL,
    FiveYrMvMed float NULL,
    TenYrMvMed float NULL
) ON [PRIMARY]

ALTER TABLE [dbo].[DailyFlow] ADD  CONSTRAINT [PK_DailyFlow] PRIMARY KEY CLUSTERED 
(
	[FlowStationID] ASC,
	[DATE] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

-- Blocking definition follow MFL of Hillsborough River near Morris Bridge
INSERT INTO DailyFlow
SELECT *,
    CASE FlowStationID 
    WHEN 6 THEN
        CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,4,20) AND DATEFROMPARTS(Year,6,24) THEN [Year]+.1 ELSE 
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,6,25) AND DATEFROMPARTS(Year,10,27) THEN [Year]+.3 ELSE
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,10,28) AND DATEFROMPARTS(Year,12,31) THEN [Year]+.2+1 ELSE
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,1,1) AND DATEFROMPARTS(Year,4,19) THEN [Year]+.2 END
        END END END 
    WHEN 22 THEN
        CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,4,12) AND DATEFROMPARTS(Year,7,21) THEN [Year]+.1 ELSE 
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,7,22) AND DATEFROMPARTS(Year,10,14) THEN [Year]+.3 ELSE
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,10,15) AND DATEFROMPARTS(Year,12,31) THEN [Year]+.2+1 ELSE
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,1,1) AND DATEFROMPARTS(Year,4,11) THEN [Year]+.2 END
        END END END 
    WHEN 24 THEN
        CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,4,25) AND DATEFROMPARTS(Year,6,23) THEN [Year]+.1 ELSE 
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,6,24) AND DATEFROMPARTS(Year,10,16) THEN [Year]+.3 ELSE
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,10,17) AND DATEFROMPARTS(Year,12,31) THEN [Year]+.2+1 ELSE
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,1,1) AND DATEFROMPARTS(Year,4,24) THEN [Year]+.2 END
        END END END 
    END 'Block'
    , AVG([Value]) OVER(PARTITION BY FlowStationID ORDER BY FlowStationID,[DATE] ROWS BETWEEN 365 PRECEDING AND 0 FOLLOWING) OneYrMvAvg
    , AVG([Value]) OVER(PARTITION BY FlowStationID ORDER BY FlowStationID,[DATE] ROWS BETWEEN 1826 PRECEDING AND 0 FOLLOWING) FiveYrMvAvg
    , AVG([Value]) OVER(PARTITION BY FlowStationID ORDER BY FlowStationID,[DATE] ROWS BETWEEN 3653 PRECEDING AND 0 FOLLOWING) TenYrMvAvg
    , NULL, NULL, NULL
FROM (
    SELECT *, YEAR([DATE]) [Year]
    FROM StreamflowTimeSeries
    WHERE FlowStationID IN (6,22,24)
) A
ORDER BY FlowStationID,[DATE]

-- Update DailyFlow Statistics
exec dbo.DailyFlow_Stats 6
exec dbo.DailyFlow_Stats 22
exec dbo.DailyFlow_Stats 24

-- Create table of flow statistics for MFL compliance
DROP TABLE IF EXISTS FlowStats_MFL
CREATE TABLE FlowStats_MFL
(
    FlowStationID int NOT NULL,
    StartDate date NOT NULL,
    EndDate date NOT NULL,
    BlockNum tinyint NULL,
    STATS_VAL float NULL,
    STATS_NAME varchar(20) NOT NULL,
    NumCount int NULL -- for checking
) ON [PRIMARY]

ALTER TABLE FlowStats_MFL ADD  CONSTRAINT [PK_FlowStats_MFL] PRIMARY KEY CLUSTERED 
(
	[FlowStationID] ASC,
	[EndDate] ASC,
    [STATS_NAME] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

INSERT INTO FlowStats_MFL
SELECT * FROM dbo.FlowStats(6)
UNION
SELECT * FROM dbo.FlowStats(22)
UNION
SELECT * FROM dbo.FlowStats(24)
;

/* For testing, dump data for stats calculation
-- no block stats
SELECT DISTINCT r.FlowStationID, r.DATE, 0 BlockNum, o.Date MvDate, [Value]
    --, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) STATS_VAL
    --, 'FiveYrMED' stats_name
    , rstart5, rend
    , COUNT([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) NumCount
FROM temp_r r
LEFT JOIN (
    SELECT FlowStationID, [Date], [Block]
        , CAST(RIGHT(CAST([Block] AS nvarchar(6)),1) AS tinyint) BlockNum
        , [Value]
        , row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
        FROM DailyFlow 
) o ON o.RowNum BETWEEN r.rstart5 AND r.rend AND r.FlowStationID=o.FlowStationID 
where r.FlowStationID=6 and (MONTH(r.DATE)=12 and DAY(r.DATE)=31)
order by r.FlowStationID, r.DATE, o.DATE

-- block flow stats
SELECT DISTINCT r.FlowStationID, r.DATE, o.Date MvDate, [Value]
    --, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) OVER(PARTITION BY r.FlowStationID,o.BlockNum) MVMED
    --, 'OneYrMED' stats_name
    --, MAX(r.DATE) OVER(PARTITION BY r.FlowStationID,o.BlockNum) BlockEndDate
    , o.Block, o.BlockNum, rstart5, rend
    , COUNT([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE,o.BlockNum) NumCount
FROM temp_r r
    LEFT JOIN (
    SELECT FlowStationID, [Date], [Block]
        , CAST(RIGHT(CAST([Block] AS nvarchar(6)),1) AS tinyint) [BlockNum]
        , [Value]
        , row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
    FROM DailyFlow 
) o ON o.RowNum BETWEEN r.rstart5 AND r.rend AND r.FlowStationID=o.FlowStationID AND r.BlockNum=o.BlockNum
where r.FlowStationID=6 and o.BlockNum=1 and (
    (MONTH(r.DATE)=4 and DAY(r.DATE)=19) or (MONTH(r.DATE)=6 and DAY(r.DATE)=24) or (MONTH(r.DATE)=10 and DAY(r.DATE)=27)
)
order by r.FlowStationID, r.DATE, o.DATE
 */


INSERT INTO FlowStats_MorrisBridge
SELECT A.FlowStationID
    , DATEADD(d,-NumCount+1,A.DATE) StartDate
    , A.DATE EndDate, BlockNum, STATS_VAL, STATS_NAME, NumCount
FROM (
-- Non Block - whole year Average
    SELECT DISTINCT FlowStationID
        , MAX([DATE]) OVER(PARTITION BY FlowStationID,[Year]) [DATE]
        , 0 BlockNum
        , AVG(o.[Value]) OVER(PARTITION BY FlowStationID,[Year]) STATS_VAL
        --, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) OVER(PARTITION BY FlowStationID,[Year]) BlockMed
        , 'AnnualAVG' STATS_NAME
        , COUNT(Value) OVER(PARTITION BY FlowStationID,[Year]) NumCount
    FROM (
        SELECT FlowStationID, [DATE], [Value], [Year]
        FROM DailyFlow
    ) o
    UNION
    SELECT DISTINCT r.FlowStationID, r.DATE, 0 BlockNum
        , AVG([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) STATS_VAL
        , 'FiveYrAVG' stats_name
        , COUNT([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) NumCount
    FROM temp_r r
    LEFT JOIN (
        SELECT FlowStationID, [Date], [Block]
            , CAST(RIGHT(CAST([Block] AS nvarchar(6)),1) AS tinyint) BlockNum
            , [Value]
            , row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM DailyFlow 
    ) o ON o.RowNum BETWEEN r.rstart5 AND r.rend AND r.FlowStationID=o.FlowStationID 
    UNION
    SELECT DISTINCT r.FlowStationID, r.DATE, 0 BlockNum
        , AVG([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) STATS_VAL
        , 'TenYrAVG' stats_name
        , COUNT([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) NumCount
    FROM temp_r r
    LEFT JOIN (
        SELECT FlowStationID, [Date], [Block]
            , CAST(RIGHT(CAST([Block] AS nvarchar(6)),1) AS tinyint) BlockNum
            , [Value]
            , row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM DailyFlow 
    ) o ON o.RowNum BETWEEN r.rstart10 AND r.rend AND r.FlowStationID=o.FlowStationID 
    
-- Non Block - whole year Median
    UNION
    SELECT DISTINCT FlowStationID
        , MAX([DATE]) OVER(PARTITION BY FlowStationID,[Year]) [DATE]
        , 0 BlockNum
        , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) OVER(PARTITION BY FlowStationID,[Year]) STATS_VAL
        , 'AnnualMED' STATS_NAME
        , COUNT(Value) OVER(PARTITION BY FlowStationID,[Year]) NumCount
    FROM (
        SELECT FlowStationID, [DATE], [Value], [Year]
        FROM DailyFlow
    ) o
    UNION
    SELECT DISTINCT r.FlowStationID, r.DATE, 0 BlockNum
        , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) STATS_VAL
        , 'FiveYrMED' stats_name
        , COUNT([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) NumCount
    FROM temp_r r
    LEFT JOIN (
        SELECT FlowStationID, [Date], [Block]
            , CAST(RIGHT(CAST([Block] AS nvarchar(6)),1) AS tinyint) BlockNum
            , [Value]
            , row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM DailyFlow 
    ) o ON o.RowNum BETWEEN r.rstart5 AND r.rend AND r.FlowStationID=o.FlowStationID 
    UNION
    SELECT DISTINCT r.FlowStationID, r.DATE, 0 BlockNum
        , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) STATS_VAL
        , 'TenYrMED' stats_name
        , COUNT([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) NumCount
    FROM temp_r r
    LEFT JOIN (
        SELECT FlowStationID, [Date], [Block]
            , CAST(RIGHT(CAST([Block] AS nvarchar(6)),1) AS tinyint) BlockNum
            , [Value]
            , row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM DailyFlow 
    ) o ON o.RowNum BETWEEN r.rstart10 AND r.rend AND r.FlowStationID=o.FlowStationID 
) A
INNER JOIN (
SELECT DISTINCT FlowStationID, [DATE]
    FROM StreamflowTimeSeries
    WHERE [DATE]>0
) B ON A.FlowStationID=B.FlowStationID AND A.DATE=B.DATE
WHERE A.FlowStationID=6 AND (MONTH(A.DATE)=12 AND DAY(A.DATE)=31)
UNION
 
SELECT A.FlowStationID
    , DATEADD(d,-NumCount+1,A.DATE) StartDate
    , A.DATE EndDate, BlockNum, STATS_VAL, STATS_NAME, NumCount
FROM (
-- Block Average
    SELECT DISTINCT r.FlowStationID, r.DATE, o.BlockNum
        , AVG([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE,o.BlockNum) STATS_VAL
        , 'OneYrAVG_Blk'+CAST(o.BlockNum AS nvarchar(1)) stats_name
        , COUNT([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE,o.BlockNum) NumCount
    FROM temp_r r
    LEFT JOIN (
        SELECT FlowStationID, [Date], [Block]
            , CAST(RIGHT(CAST([Block] AS nvarchar(6)),1) AS tinyint) BlockNum
            , [Value]
            , row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM DailyFlow 
    ) o ON o.RowNum BETWEEN r.rstart1 AND r.rend AND r.FlowStationID=o.FlowStationID AND r.BlockNum=o.BlockNum
    UNION
    SELECT DISTINCT r.FlowStationID, r.DATE, o.BlockNum
        , AVG([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) STATS_VAL
        , 'FiveYrAVG_Blk'+CAST(o.BlockNum AS nvarchar(1)) stats_name
        , COUNT([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE,o.BlockNum) NumCount
    FROM temp_r r
    LEFT JOIN (
        SELECT FlowStationID, [Date], [Block]
            , CAST(RIGHT(CAST([Block] AS nvarchar(6)),1) AS tinyint) BlockNum
            , [Value]
            , row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM DailyFlow 
    ) o ON o.RowNum BETWEEN r.rstart5 AND r.rend AND r.FlowStationID=o.FlowStationID AND r.BlockNum=o.BlockNum
    UNION
    SELECT DISTINCT r.FlowStationID, r.DATE, o.BlockNum
        , AVG([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) STATS_VAL
        , 'TenYrAVG_Blk'+CAST(o.BlockNum AS nvarchar(1)) stats_name
        , COUNT([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE,o.BlockNum) NumCount
    FROM temp_r r
    LEFT JOIN (
        SELECT FlowStationID, [Date], [Block]
            , CAST(RIGHT(CAST([Block] AS nvarchar(6)),1) AS tinyint) BlockNum
            , [Value]
            , row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM DailyFlow 
    ) o ON o.RowNum BETWEEN r.rstart10 AND r.rend AND r.FlowStationID=o.FlowStationID AND r.BlockNum=o.BlockNum

-- Block Median
    UNION
    SELECT DISTINCT r.FlowStationID, r.DATE, o.BlockNum
        , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) OVER(PARTITION BY r.FlowStationID,r.DATE,o.BlockNum) STATS_VAL
        , 'OneYrMED_Blk'+CAST(o.BlockNum AS nvarchar(1)) stats_name
        , COUNT([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE,o.BlockNum) NumCount
    FROM temp_r r
    LEFT JOIN (
        SELECT FlowStationID, [Date], [Block]
            , CAST(RIGHT(CAST([Block] AS nvarchar(6)),1) AS tinyint) BlockNum
            , [Value]
            , row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM DailyFlow 
    ) o ON o.RowNum BETWEEN r.rstart1 AND r.rend AND r.FlowStationID=o.FlowStationID AND r.BlockNum=o.BlockNum
    UNION
    SELECT DISTINCT r.FlowStationID, r.DATE, o.BlockNum
        , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) STATS_VAL
        , 'FiveYrMED_Blk'+CAST(o.BlockNum AS nvarchar(1)) stats_name
        , COUNT([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE,o.BlockNum) NumCount
    FROM temp_r r
    LEFT JOIN (
        SELECT FlowStationID, [Date], [Block]
            , CAST(RIGHT(CAST([Block] AS nvarchar(6)),1) AS tinyint) BlockNum
            , [Value]
            , row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM DailyFlow 
    ) o ON o.RowNum BETWEEN r.rstart5 AND r.rend AND r.FlowStationID=o.FlowStationID AND r.BlockNum=o.BlockNum
    UNION
    SELECT DISTINCT r.FlowStationID, r.DATE, o.BlockNum
        , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) STATS_VAL
        , 'TenYrMED_Blk'+CAST(o.BlockNum AS nvarchar(1)) stats_name
        , COUNT([Value]) OVER(PARTITION BY r.FlowStationID,r.DATE,o.BlockNum) NumCount
    FROM temp_r r
    LEFT JOIN (
        SELECT FlowStationID, [Date], [Block]
            , CAST(RIGHT(CAST([Block] AS nvarchar(6)),1) AS tinyint) BlockNum
            , [Value]
            , row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM DailyFlow 
    ) o ON o.RowNum BETWEEN r.rstart10 AND r.rend AND r.FlowStationID=o.FlowStationID AND r.BlockNum=o.BlockNum
) A
INNER JOIN (
SELECT DISTINCT FlowStationID, [DATE]
    FROM StreamflowTimeSeries
    WHERE [DATE]>0
) B ON A.FlowStationID=B.FlowStationID AND A.DATE=B.DATE
where A.FlowStationID=6 and (
    (MONTH(A.DATE)=4 and DAY(A.DATE)=19) or (MONTH(A.DATE)=6 and DAY(A.DATE)=24) or (MONTH(A.DATE)=10 and DAY(A.DATE)=27)
)

--ORDER BY FlowStationID,[DATE],BlockNum,stats_name
