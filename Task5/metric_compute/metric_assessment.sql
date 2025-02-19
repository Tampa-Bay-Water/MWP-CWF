DECLARE @RUNID AS INT = -1 -- RunID per scenario
DECLARE @use_stats AS VARCHAR(15) = 'P10' -- use with @TARGET_CRITERIA to handle target uncertainty
DECLARE @TARGET_CRITERIA AS FLOAT = 0.5 
DECLARE @Metric AS VARCHAR(25) = 'med08_severity' -- 8-Year Moving Median
DECLARE @netwk_pass_pct AS FLOAT = 50. -- monitoring network passing criteria in percent
DECLARE @temp_table AS TABLE (
    [REALIZATIONID] SMALLINT    NOT NULL,
    [DataType]      VARCHAR(10)  NOT NULL,
    [PointName]     VARCHAR(20) NOT NULL,
    [Stats Value]   FLOAT       NULL,
    [WellPass]      FLOAT       NULL
)
;

IF OBJECT_ID('tempdb.dbo.#temp_metric', 'U') IS NOT NULL
    DROP TABLE #temp_metric
;
SELECT RealizationID,DataType,LocID,PointName,Metric,[Stats],round([Value],3) Value
INTO #temp_metric
FROM [MWP_CWF_metric].[dbo].[Metric] A
LEFT JOIN (
    select PointID,PointName from MWP_CWF.[dbo].[OROP_SASwells]
    UNION
    select PointID,PointName from MWP_CWF.[dbo].[OROP_UFASwells]
) B ON A.LOCID=B.PointID
WHERE RunID=@RUNID
;

-- Metric table
select * from #temp_metric
ORDER BY RealizationID,DataType,PointName,Metric,[Stats]
;

-- Add WellPass metric column based on @P10_CRITERIA and filter for @Metric of interest

INSERT INTO @temp_table
SELECT RealizationID,DataType,PointName,[Value] [Stats Value]
    ,CASE WHEN Value<=@TARGET_CRITERIA THEN 1.0 ELSE 0. END WellPass
FROM #temp_metric
WHERE Metric=@Metric AND STATS=@use_stats
ORDER BY RealizationID,DataType,PointName
;
;
SELECT * FROM @temp_table
ORDER BY RealizationID,DataType,PointName
;
-- Compute Monitoring Network Passing Metric
SELECT RealizationID,DataType,ROUND(Monitor_NetworkPass,2) Monitor_NetworkPass
FROM (
    SELECT RealizationID,DataType,AVG(WellPass)*100 Monitor_NetworkPass
    FROM @temp_table
    GROUP BY RealizationID,DataType
) A
ORDER BY RealizationID,DataType
;

-- Monitoring Network Assessment
SELECT DataType
    , RealizationID,CASE WHEN Monitor_NetworkPass>=@netwk_pass_pct THEN 1.0 ELSE 0.0 END MonitoringNetWorkPass
--    , AVG(CASE WHEN Monitor_NetworkPass>=@netwk_pass_pct THEN 1.0 ELSE 0.0 END) Reliability
FROM (
    SELECT RealizationID,DataType,AVG(WellPass)*100 Monitor_NetworkPass
    FROM @temp_table
    GROUP BY RealizationID,DataType
) A
;

-- Reliability
SELECT DataType
    , AVG(CASE WHEN Monitor_NetworkPass>=@netwk_pass_pct THEN 1.0 ELSE 0.0 END)*100. Reliability
FROM (
    SELECT RealizationID,DataType,AVG(WellPass)*100 Monitor_NetworkPass
    FROM @temp_table
    GROUP BY RealizationID,DataType
) A
GROUP BY DataType

-- Check by RealizationID
SELECT RealizationID,DataType,PointName,WellPass
FROM @temp_table
WHERE RealizationID=6 AND DataType='OROP_CP'
ORDER BY RealizationID,DataType,PointName