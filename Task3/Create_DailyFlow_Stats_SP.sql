CREATE OR ALTER PROCEDURE dbo.DailyFlow_Stats (@staid smallint)
AS
BEGIN
-- DECLARE @STAID SMALLINT = 6;
DECLARE @r AS TABLE (
    FlowStationID int not null,
    [DATE] DateTime not null,
    rstart1 int NULL,
    rstart5 int NULL,
    rstart10 int NULL,
    rend int NULL,
    BlockNum tinyint NULL
);
INSERT INTO @r 
SELECT FlowStationID, [DATE], rstart1, rstart5, rstart10, rend,
    CASE FlowStationID 
    WHEN 6 THEN
        CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,4,20) AND DATEFROMPARTS(Year,6,24) THEN 1 ELSE 
        CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,6,25) AND DATEFROMPARTS(Year,10,27) THEN 3 ELSE
        CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,10,28) AND DATEFROMPARTS(Year,12,31) THEN 2 ELSE
        CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,1,1) AND DATEFROMPARTS(Year,4,19) THEN 2 END
    END END END 
    WHEN 22 THEN
        CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,4,12) AND DATEFROMPARTS(Year,7,21) THEN 1 ELSE 
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,7,22) AND DATEFROMPARTS(Year,10,14) THEN 3 ELSE
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,10,15) AND DATEFROMPARTS(Year,12,31) THEN 2 ELSE
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,1,1) AND DATEFROMPARTS(Year,4,11) THEN 2 END
        END END END 
    WHEN 24 THEN
        CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,4,25) AND DATEFROMPARTS(Year,6,23) THEN 1 ELSE 
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,6,24) AND DATEFROMPARTS(Year,10,16) THEN 3 ELSE
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,10,17) AND DATEFROMPARTS(Year,12,31) THEN 2 ELSE
            CASE WHEN [DATE] BETWEEN DATEFROMPARTS(Year,1,1) AND DATEFROMPARTS(Year,4,24) THEN 2 END
        END END END 
    END BlockNum
FROM (
    SELECT [DATE], YEAR([DATE]) [Year]
        , row_number() OVER(ORDER BY [DATE]) - 364 rstart1
        , row_number() OVER(ORDER BY [DATE]) - 1825 rstart5
        , row_number() OVER(ORDER BY [DATE]) - 3652 rstart10
        , row_number() OVER(ORDER BY [DATE]) rend
    FROM (
        SELECT distinct [DATE]
        FROM StreamflowTimeSeries
        WHERE FlowStationID=@staid
    ) d
) a, (
    SELECT distinct FlowStationID
    FROM StreamflowTimeSeries
    WHERE FlowStationID=@staid
) b
WHERE [DATE]>0 AND FlowStationID=@staid
ORDER BY FlowStationID,[DATE],[BlockNum];
-- select * from @r ORDER BY FlowStationID,[DATE],[BlockNum];

DECLARE @o TABLE (
    FlowStationID int NOT NULL,
    [DATE] date NOT NULL,
    OneYr_MVMED float NULL,
    FiveYr_MVMED float NULL,
    TenYr_MVMED float NULL
);
INSERT INTO @o
SELECT FlowStationID, [DATE], OneYr_MVMED, FiveYr_MVMED, TenYr_MVMED
FROM (
    SELECT A.FlowStationID, A.DATE [DATE], MVMED, MVMED_NAME
    FROM (
        SELECT DISTINCT r.FlowStationID, r.DATE
            , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) MVMED
            , 'OneYr_MVMED' mvmed_name
        FROM @r r
        LEFT JOIN (
            SELECT *, row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM StreamflowTimeSeries 
            WHERE FlowStationID=@staid
        ) o ON o.RowNum BETWEEN r.rstart1 AND r.rend AND r.FlowStationID=o.FlowStationID
        UNION
        SELECT DISTINCT r.FlowStationID, r.DATE
            , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) MVMED
            , 'FiveYr_MVMED' mvmed_name
        FROM @r r
        LEFT JOIN (
            SELECT *, row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM StreamflowTimeSeries 
            WHERE FlowStationID=@staid
        ) o ON o.RowNum BETWEEN r.rstart5 AND r.rend AND r.FlowStationID=o.FlowStationID
        UNION
        SELECT DISTINCT r.FlowStationID, r.DATE
            , PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Value]) OVER(PARTITION BY r.FlowStationID,r.DATE) MVMED
            , 'TenYr_MVMED' mvmed_name
        FROM @r r
        LEFT JOIN (
            SELECT *, row_number() OVER(PARTITION by FlowStationID ORDER BY [DATE]) RowNum
            FROM StreamflowTimeSeries 
            WHERE FlowStationID=@staid
        ) o ON o.RowNum BETWEEN r.rstart10 AND r.rend AND r.FlowStationID=o.FlowStationID
    ) A
    INNER JOIN (
        SELECT DISTINCT FlowStationID, [DATE]
        FROM StreamflowTimeSeries
        WHERE [DATE]>0 AND FlowStationID=@staid
    ) B ON A.FlowStationID=B.FlowStationID AND A.DATE=B.DATE
) X PIVOT (
    AVG(MVMED) FOR MVMED_NAME IN (OneYr_MVMED,FiveYr_MVMED,TenYr_MVMED)
) P
-- select * from @o order by FlowStationID,DATE

UPDATE DailyFlow
    SET DailyFlow.OneYrMvMed= o.OneYr_MVMED,
        DailyFlow.FiveYrMvMed=o.FiveYr_MVMED,
        DailyFlow.TenYrMvMed= o.TenYr_MVMED
FROM @o o
WHERE DailyFlow.FlowStationID=o.FlowStationID AND DailyFlow.[DATE]=o.DATE

RETURN
END