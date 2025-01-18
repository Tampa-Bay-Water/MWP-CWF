--- Create table for flow statistics by block
DROP TABLE IF EXISTS [dbo].[RA_BlockFlow];
CREATE TABLE RA_BlockFlow  (
    FlowStationID INT NOT NULL,
    [Year] SMALLINT NOT NULL,
    BlkNum TINYINT NOT NULL,
    StartDate DATE NULL,
    EndDate DATE NULL,
    BlkAvg FLOAT NULL,
    BlkMed FLOAT NULL,
    RowNum INT NOT NULL
)
;
ALTER TABLE [dbo].[RA_BlockFlow] ADD  CONSTRAINT [PK_RA_BlockFlow] PRIMARY KEY CLUSTERED 
(
	[FlowStationID] ASC,
    [Year] ASC,
	[BlkNum] ASC
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
;
INSERT INTO RA_BlockFlow
--- Block Stats
SELECT *,row_number() OVER(PARTITION by FlowStationID,[BlkNum] ORDER BY [Year]) RowNum
FROM (
SELECT distinct FlowStationID,round(Block,0) [Year],10*[Block]-10*(round([Block],0)) BlkNum
    ,min([Date]) over (PARTITION BY FlowStationID,[Block]) StartDate
    ,max([Date]) over (PARTITION BY FlowStationID,[Block]) EndDate
    ,avg([Value]) over (PARTITION BY FlowStationID,[Block]) BlkAvg
    ,PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) 
        OVER(PARTITION BY FlowStationID,[Block]) BlkMed
    
FROM DailyFlow
UNION
SELECT distinct FlowStationID,[Year],0 BlkNum
    ,min([Date]) OVER (PARTITION BY FlowStationID,[Year]) StartDate
    ,max([Date]) OVER (PARTITION BY FlowStationID,[Year]) EndDate
    ,avg([Value]) OVER (PARTITION BY FlowStationID,[Year]) BlkAvg
    ,PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) 
        OVER(PARTITION BY FlowStationID,[Year]) BlkMed
FROM DailyFlow
) A 
ORDER BY FlowStationID,BlkNum,[Year]
;

/*
--- Compute 5 years and 10 years moving statistics over block stats
DECLARE @flowstats TABLE (
    FlowStationID INT NOT NULL,
    BlkNum TINYINT NOT NULL,
    [Year] SMALLINT NOT NULL,
    --StartDate DATE NULL,
    --EndDate DATE NULL,
    StatsType NVARCHAR(15) NULL,
    [Value] FLOAT NULL
)
;
--- defind table for cumulative range
with r_cte AS (
    SELECT [FlowStationID],[Year],BlkNum
        ,row_number() OVER(PARTITION BY FlowStationID,BlkNum ORDER BY [Year])-4 rstart5
        ,row_number() OVER(PARTITION BY FlowStationID,BlkNum ORDER BY [Year])-9 rstart10
        ,row_number() OVER(PARTITION BY FlowStationID,BlkNum  ORDER BY [Year]) rend
    FROM RA_BlockFlow
)
INSERT INTO @flowstats
SELECT distinct r.FlowStationID,r.BlkNum
    --,o.[Year],o.RowNum,o.BlkMed
    ,r.Year,'FiveYrMed' StatsType
    --,r.rstart5,r.rend
    ,PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [BlkMed])
        OVER (PARTITION BY r.FlowStationID,r.BlkNum,r.Year) Value
FROM RA_BlockFlow o
right join r_cte r ON o.FlowStationID=r.FlowStationID and o.BlkNum=r.BlkNum and RowNum BETWEEN rstart5 and rend
where rstart5>0
union
SELECT distinct r.FlowStationID,r.BlkNum
    --,o.[Year],o.RowNum,o.BlkMed
    ,r.Year,'TenYrMed' StatsType
    --,r.rstart10,r.rend
    ,PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [BlkMed])
        OVER (PARTITION BY r.FlowStationID,r.BlkNum,r.Year) Value
FROM RA_BlockFlow o
right join r_cte r ON o.FlowStationID=r.FlowStationID and o.BlkNum=r.BlkNum and RowNum BETWEEN rstart10 and rend
where rstart10>0
UNION
select FlowStationID,BlkNum,[Year],'FiveYrAvg' StatsType
    ,AVG(BlkAvg) OVER (PARTITION BY FlowStationID,BlkNum ORDER BY [Year] 
        ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) [Value]
FROM RA_BlockFlow
UNION
select FlowStationID,BlkNum,[Year],'TenYrAvg' StatsType
    ,AVG(BlkAvg) OVER (PARTITION BY FlowStationID,BlkNum ORDER BY [Year] 
        ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) [Value]
FROM RA_BlockFlow
ORDER BY r.FlowStationID,r.BlkNum,StatsType,r.[Year] --,o.RowNum
;

/*
select FlowStationID,BlkNum,[Year],StartDate,EndDate
    ,FiveYrAvg,TenYrAVG,FiveYrMed,TenYrMed
from (
    select fs.*,bs.StartDate,bs.EndDate
    from @flowstats fs
    inner join RA_BlockFlow bs on fs.FlowStationID=bs.FlowStationID and fs.BlkNum=bs.BlkNum and fs.[Year]=bs.[Year]
) A
pivot (max(Value) for StatsType in (FiveYrAvg,TenYrAVG,FiveYrMed,TenYrMed)) B
ORDER BY FlowStationID,BlkNum,[Year]
*/
*/

DECLARE @minyr INT
SELECT @minyr=min([Year]) FROM DailyFlow
;
DECLARE @flowdaily TABLE (
    FlowStationID INT NOT NULL,
    BlkNum TINYINT NULL,
    [Date] DATE NOT NULL,
    [Year] SMALLINT NOT NULL,
    [Value] FLOAT NULL,
    RowNum INT NULL
)
;
INSERT INTO @flowdaily
SELECT FlowStationID
    ,10*[Block]-10*(round([Block],0)) BlkNum
    ,[Date]
    ,round([Block],0) [Year],[Value]
    --,[Year],[Value]
    --,row_number() OVER (PARTITION BY FlowStationID,[Block],[Year] ORDER BY [Year]) RowNum
    ,round([Block],0)-@minyr+1 RowNum
FROM DailyFlow
UNION
SELECT FlowStationID
    ,0 BlkNum
    ,[Date]
    ,[Year],[Value]
    ,[Year]-@minyr+1 RowNum
FROM DailyFlow
ORDER BY FlowStationID,[Date]
;
/*
SELECT * FROM @flowdaily
--where BlkNum=2 and RowNum<=5
ORDER BY FlowStationID,BlkNum,[Date]

;
    SELECT distinct [FlowStationID],[Year],BlkNum
        ,[Year]-@minyr-3 rstart5
        ,[Year]-@minyr-8 rstart10
        ,[Year]-@minyr+1 rend
    FROM @flowdaily
    order by [FlowStationID],BlkNum,[Year]
;
*/
--- Compute 5 years and 10 years moving statistics over block flow
DECLARE @flowstats TABLE (
    FlowStationID INT NOT NULL,
    BlkNum TINYINT NOT NULL,
    [Year] SMALLINT NOT NULL,
    StatsType NVARCHAR(15) NULL,
    [Value] FLOAT NULL
)
;
--- defind table for cumulative range
with r_cte AS (
    SELECT distinct [FlowStationID],[Year],BlkNum
        ,[Year]-@minyr-3 rstart5
        ,[Year]-@minyr-8 rstart10
        ,[Year]-@minyr+1 rend
    FROM @flowdaily
)
INSERT INTO @flowstats
SELECT distinct 
    r.FlowStationID,r.BlkNum
    ,r.Year,'FiveYrAvg' StatsType
    ,AVG(Value) OVER(PARTITION BY o.FlowStationID,o.BlkNum,r.Year) StatsValue
FROM @flowdaily o
left join r_cte r ON o.FlowStationID=r.FlowStationID and o.BlkNum=r.BlkNum and RowNum BETWEEN rstart5 and rend
where rstart5>0
UNION
SELECT distinct 
    r.FlowStationID,r.BlkNum
    ,r.Year,'FiveYrMed' StatsType
    ,PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value])
        OVER (PARTITION BY r.FlowStationID,r.BlkNum,r.Year) Value
FROM @flowdaily o
left join r_cte r ON o.FlowStationID=r.FlowStationID and o.BlkNum=r.BlkNum and RowNum BETWEEN rstart5 and rend
where rstart5>0
UNION
SELECT distinct 
    r.FlowStationID,r.BlkNum
    ,r.Year,'TenYrAvg' StatsType
    ,AVG(Value) OVER(PARTITION BY o.FlowStationID,o.BlkNum,r.Year) StatsValue
FROM @flowdaily o
left join r_cte r ON o.FlowStationID=r.FlowStationID and o.BlkNum=r.BlkNum and RowNum BETWEEN rstart10 and rend
where rstart10>0
UNION
SELECT distinct 
    r.FlowStationID,r.BlkNum
    ,r.Year,'TenYrMed' StatsType
    ,PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value])
        OVER (PARTITION BY r.FlowStationID,r.BlkNum,r.Year) Value
FROM @flowdaily o
left join r_cte r ON o.FlowStationID=r.FlowStationID and o.BlkNum=r.BlkNum and RowNum BETWEEN rstart10 and rend
where rstart10>0
order by r.FlowStationID,r.BlkNum,r.[Year]

select * 
from @flowstats
--where FlowStationID=6 and BlkNum=2 and StatsType='FiveYrAvg'
order by FlowStationID,BlkNum,StatsType,[Year]

--- Unpivot Start and EndDate to create time series suitable for plotting
DROP TABLE IF EXISTS [dbo].[RA_BlkFlowMFL_Stats];
CREATE TABLE [dbo].[RA_BlkFlowMFL_Stats](
	[FlowStationID] [int] NOT NULL,
	[BlkNum] [tinyint] NOT NULL,
	[Date] [date] NOT NULL,
	[StatsType] [nvarchar](15) NOT NULL,
	[Value] [float] NULL
) ON [PRIMARY]
;
ALTER TABLE [dbo].[RA_BlkFlowMFL_Stats] ADD  CONSTRAINT [PK_RA_BlkFlowMFL_Stats] PRIMARY KEY CLUSTERED 
(
	[FlowStationID] ASC,
	[BlkNum] ASC,
	[Date] ASC,
	[StatsType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
insert into RA_BlkFlowMFL_Stats
select FlowStationID,BlkNum,[Date],StatsType,[Value]
from (
    select fs.*,bs.StartDate,bs.EndDate
    from @flowstats fs
    inner join RA_BlockFlow bs on fs.FlowStationID=bs.FlowStationID and fs.BlkNum=bs.BlkNum and fs.[Year]=bs.[Year]
) A
unpivot ([Date] for DateType in (StartDate,EndDate)) B
ORDER BY FlowStationID,BlkNum,[Date]
;

---Unpivot table for ploting
SELECT FlowStationID,BlkNum,[Date],BlkAvg,BlkMed
FROM RA_BlockFlow A
UNPIVOT ([Date] FOR DateCat IN (StartDate,EndDate)) B
WHERE BlkNum=0 ORDER BY FlowStationID,[Date]
;
SELECT FlowStationID,BlkNum,[Date],BlkAvg,BlkMed
FROM RA_BlockFlow A
UNPIVOT ([Date] FOR DateCat IN (StartDate,EndDate)) B
WHERE BlkNum>0 ORDER BY FlowStationID,[Date]
;

select FlowStationID,BlkNum,[Date],FiveYrAvg,TenYrAvg,FiveYrMed,TenYrMed
from RA_BlkFlowMFL_Stats A
pivot (avg(Value) for StatsType in (FiveYrAvg,TenYrAvg,FiveYrMed,TenYrMed)) B
where FlowStationID=6 and BlkNum>0
ORDER BY FlowStationID,[Date]
;
select FlowStationID,BlkNum,[Date],FiveYrAvg,TenYrAvg,FiveYrMed,TenYrMed
from RA_BlkFlowMFL_Stats A
pivot (avg(Value) for StatsType in (FiveYrAvg,TenYrAvg,FiveYrMed,TenYrMed)) B
where FlowStationID=6 and BlkNum=0
ORDER BY FlowStationID,[Date]
;


DROP TABLE IF EXISTS [dbo].[mfl_ts];
CREATE TABLE mfl_ts (
    FlowStationID int NOT NULL,
    BlockNum tinyint NOT NULL,
    [Date] DATE,
    MFL_FiveYrAVG float,
    MFL_FiveYrMED float,
    MFL_TenYrAVG float,
    MFL_TenYrMED float
)
;
WITH cte AS (
    SELECT FlowStationID,BlockNum,FiveYrAVG,FiveYrMED,TenYrAVG,TenYrMED
        ,DATEFROMPARTS([Year],StartDateMonth,StartDateDay) StartDate
        ,DATEFROMPARTS([Year],EndDateMonth,EndDateDay) EndDate 
    FROM (
        SELECT FlowStationID,BlockNum,Type T,[Value]
        FROM [dbo].[MinimumFlowTable]
        UNION
        SELECT FlowStationID,BlockNum,[Type]+Tier t,[Value] 
        FROM (
            SELECT *
            FROM [dbo].[MinimumFlowTable]
            WHERE type in ('StartDate','EndDate')
        ) A
    ) A PIVOT (AVG(Value) for T in (FiveYrAVG,FiveYrMED,TenYrAVG,TenYrMED,StartDateDay,StartDateMonth,EndDateDay,EndDateMonth)) B
    RIGHT JOIN (
        select distinct BlkNum,Year(Date) [Year] FROM RA_BlkFlowMFL_Stats
    ) C ON B.BlockNum=C.BlkNum
)
INSERT into mfl_ts
SELECT FlowStationID,BlockNum,[Date],FiveYrAVG,FiveYrMED,TenYrAVG,TenYrMED
FROM cte
UNPIVOT ([Date] for DateName in (StartDate,EndDate)) B
ORDER BY FlowStationID,[Date]

                SELECT CAST(A.[Date] AS DATETIME) [Date],FiveYrAvg,FiveYrMed,MFL_FiveYrAVG,MFL_FiveYrMED
                FROM (
                    SELECT FlowStationID,BlkNum,[Date],FiveYrAvg,FiveYrMed
                    FROM RA_BlkFlowMFL_Stats A
                    pivot (avg(Value) for StatsType in (FiveYrAvg,FiveYrMed)) B
                ) A
                INNER JOIN mfl_ts B ON A.Date=B.Date and A.FlowStationID=B.FlowStationID and A.BlkNum=B.BlockNum
                where A.BlkNum>0 and A.FlowStationID=6 and A.Date between '10/1/2007' and '9/30/2023'
                ORDER BY [Date]            
