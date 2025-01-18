CREATE OR ALTER FUNCTION dbo.FlowStats(@staid AS smallint) 
RETURNS @rettab TABLE (
    FlowStationID int NOT NULL,
    StartDate date NOT NULL,
    EndDate date NOT NULL,
    BlockNum tinyint NULL,
    STATS_VAL float NULL,
    STATS_NAME varchar(20) NOT NULL,
    NumCount int NULL -- for checking
)
AS
BEGIN
DECLARE @blk1_edate_day as int;
DECLARE @blk2_edate_day as int;
DECLARE @blk3_edate_day as int;
DECLARE @blk1_edate_month as int;
DECLARE @blk2_edate_month as int;
DECLARE @blk3_edate_month as int;
select @blk1_edate_day=[value] from MinimumFlowTable where FlowStationID=@staid and BlockNum=1 and Type='EndDate' and Tier='Day';
select @blk2_edate_day=[value] from MinimumFlowTable where FlowStationID=@staid and BlockNum=2 and Type='EndDate' and Tier='Day';
select @blk3_edate_day=[value] from MinimumFlowTable where FlowStationID=@staid and BlockNum=3 and Type='EndDate' and Tier='Day';
select @blk1_edate_month=[value] from MinimumFlowTable where FlowStationID=@staid and BlockNum=1 and Type='EndDate' and Tier='Month';
select @blk2_edate_month=[value] from MinimumFlowTable where FlowStationID=@staid and BlockNum=2 and Type='EndDate' and Tier='Month';
select @blk3_edate_month=[value] from MinimumFlowTable where FlowStationID=@staid and BlockNum=3 and Type='EndDate' and Tier='Month';

INSERT INTO @rettab
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
WHERE A.FlowStationID=@staid AND (MONTH(A.DATE)=12 AND DAY(A.DATE)=31)
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
where A.FlowStationID=@staid and (
    (MONTH(A.DATE)=@blk1_edate_month and DAY(A.DATE)=@blk1_edate_day) or 
    (MONTH(A.DATE)=@blk2_edate_month and DAY(A.DATE)=@blk2_edate_day) or 
    (MONTH(A.DATE)=@blk3_edate_month and DAY(A.DATE)=@blk3_edate_day)
)
RETURN
END

