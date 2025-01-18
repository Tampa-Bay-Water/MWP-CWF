/*
CREATE OR ALTER FUNCTION dbo.GENERATE_DAILYCAL(
    @sdate date = '10/01/2007',
    @edate date = '09/30/2023'
)
RETURNS TABLE
RETURN (
    select DATEADD(DAY,t.value,@sdate) TSTAMP
    from generate_series(0,DATEDIFF(DAY,@sdate,@edate),1) t
);
*/
select * from dbo.GENERATE_DAILYCAL(default,default);

/*
CREATE OR ALTER FUNCTION dbo.DAILYCAL_LAG_STARTDATE(
    @sdate date = '10/01/2007',
    @edate date = '09/30/2023',
    @numyr tinyint = 1
)
RETURNS @RA_CAL table(
    TSTAMP DATE,
    sdate_lag DATE
)
BEGIN
    insert into @RA_CAL
    select TSTAMP,
        case when MONTH(c.tstamp)=2 and DAY(c.tstamp)=29 and (YEAR(c.tstamp)-@numyr)%4<>0
        then DATEFROMPARTS(YEAR(c.TSTAMP)-@numyr,MONTH(c.TSTAMP),28)
        else DATEFROMPARTS(YEAR(c.TSTAMP)-@numyr,MONTH(c.TSTAMP),DAY(c.TSTAMP))
        end sdate_lag
    from GENERATE_DAILYCAL(@sdate,@edate) c
    RETURN
END;
*/
select * from dbo.DAILYCAL_LAG_STARTDATE(default,default,default) order by TSTAMP;

/*
CREATE OR ALTER FUNCTION dbo.DAILYCAL_MOVINGLAG(
    @sdate date = '10/01/2007',
    @edate date = '09/30/2023',
    @numyr tinyint = 1
)
RETURNS TABLE AS
RETURN
(
    with cte_recur as (
        select TSTAMP
            , TSTAMP movingdate
            , 1 rowno
        from dbo.DAILYCAL_LAG_STARTDATE(@sdate,@edate,@numyr)
        union ALL
        select f.[TSTAMP]
            , DATEADD(DAY,-1,movingdate) movingdate
            , rowno+1
        from dbo.DAILYCAL_LAG_STARTDATE(@sdate,@edate,@numyr) f
        inner join cte_recur r on f.TSTAMP=r.TSTAMP
        where r.movingdate>DATEADD(DAY,1,f.sdate_lag)
    )
    select * from cte_recur 
    --order by TSTAMP,rowno
    --OPTION(MAXRECURSION 3660)
);
*/
select * from dbo.DAILYCAL_MOVINGLAG(default,default,10) order by TSTAMP,movingdate desc OPTION(MAXRECURSION 3660)
