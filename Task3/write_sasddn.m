saved_fname = 'task3_3_saved.mat';
load(saved_fname,'ddn1','tstamp2','cellid','urm_wkno');
urm_nowk = length(urm_wkno);
DDN = 0.-ddn1(1:(size(ddn1,1)-urm_nowk),:);
DDN = reshape(DDN,numel(DDN),1);
DDN_1 = max(DDN-1,0);
DDN_2 = max(DDN-2,0);
Tstamp = cellfun(@(y) y(1:10),tstamp2,'UniformOutput',false);
Tstamp = repmat(Tstamp,length(cellid),1);
CellID = reshape(repmat(cellid',length(tstamp2),1),numel(DDN),1);
t_ddn = table(CellID,Tstamp,DDN,DDN_1,DDN_2,...
    'VariableNames',{'CellID','Date','SASDDN','Above1ft','Above2ft'});
writetable(t_ddn,'sasddn.csv');

%{
% SQL for Weekly_Pumpaage
select SCADAName,CAST(WeekStartDate as Date) WeekStartDate
    ,round(WeeklyPumpage,3) Pumpage
    ,round(case when WeeklyPumpage>0.5 then WeeklyPumpage-0.5 else 0 end,3) Pumpage05
    ,round(case when WeeklyPumpage>1.0 then WeeklyPumpage-1.0 else 0 end,3) Pumpage10
    ,round(case when WeeklyPumpage<=1.0 then WeeklyPumpage else 0 end,3) Pumpage_10
    ,round(case when WeeklyPumpage>1.5 then WeeklyPumpage-1.5 else 0 end,3) Pumpage15
from [dbo].[RA_WeeklyPumpage]
where WeekStartDate between '10/1/2013' and '9/30/2019'
order by SCADAName,WeekStartDate

% SQL for Weekly_OROP_RLO
select A.PointName,CAST(WeekStartDate as Date) WeekStartDate
    ,round([SixYr_MVMED]-TargetWL,3)  RLO_med6yr
    ,round([EightYr_MVMED]-TargetWL,3)  RLO_med8yr
    ,round(case when [SixYr_MVMED]>TargetWL then 0 else TargetWL-[SixYr_MVMED] end,3) NegRLO_med6yr
    ,round(case when [EightYr_MVMED]>TargetWL then 0 else TargetWL-[EightYr_MVMED] end,3) NegRLO_med8yr
from [dbo].[RA_SAS_WeeklyWL_MVMED] A
INNER JOIN (
    select * from [dbo].[RA_TargetWL]  where newTarget is not null and PointName<>'WRW-s'
) B on A.PointName=B.PointName
where WeekStartDate between '10/1/2013' and '9/30/2019' 
order by A.PointName,WeekStartDate
%}

if ispc
    dv = 'SQL Server Native Client 11.0';
    sv = 'vgridfs';
    conn = database(['Driver=' dv ';Server=' sv ';Database=OROP_Data2' ...
        ';Trusted_Connection=Yes;LoginTimeout=300;']);
    d_shapefile = 'F:\IHM\shapefiles';
end 
if ismac
    conn = odbc('MWP_CWF','SA',getenv('SA_PASSWORD'));
    d_shapefile = '/Volumes/Mac_xSSD/Shapefiles';
end
DDN = fetch(conn,[...
    'select CellID,Date,SASDDN ',...
    'from openrowset(BULK ''/home/mssql/MWP-CWUP/sasddn.csv''',...
    ',FORMATFILE = ''/home/mssql/MWP-CWUP/ddn_csv_format.xml''',...
    ',FIRSTROW = 2) A']);
DDN.Date = datetime(DDN.Date);
cellid = unique(DDN.CellID);

OROP_SASwells = shaperead(fullfile(d_shapefile,'OROP_SASwells.shp'));
OROP_SASwells = struct2table(OROP_SASwells);
OROP_CWF = fetch(conn,[...
    'select PointName,TargetWL ',...
    'from RA_TargetWL ',...
    'where newTarget is not null and PointName not in (''WRW-s'',''BUD-14fl'',''BUD-21fl'')' ...
    ]);
temp = innerjoin(OROP_SASwells,OROP_CWF,'LeftKeys', {'WellName'}, 'RightKeys', {'PointName'});
OROP_CWF = temp(:,{'WellName','CTSID','WFCode','CellID','X','Y','TargetWL'});

INTBgrid_centroid = shaperead(fullfile(d_shapefile,'INTBgrid_centroid.shp'));
INTBgrid_centroid = struct2table(INTBgrid_centroid);
gridid = INTBgrid_centroid.GRIDID;
nwells = height(OROP_CWF);
OROP_ROI = zeros(nwells,height(INTBgrid_centroid),"logical");
for i=1:nwells
    OROP_ROI(i,:) = OROP_ROI(i,:) + arrayfun(@(y) sqrt(...
        (INTBgrid_centroid.X(y)-OROP_CWF.X(i))^2 + (INTBgrid_centroid.Y(y)-OROP_CWF.Y(i))^2 ...
        )<1609.344*5.0,...
        1:height(INTBgrid_centroid));
end
temp = sum(OROP_ROI,1);
max(temp)

% Determine R-square
OROP_CORR = zeros(nwells,height(INTBgrid_centroid));
% parpool(10);
% parfor i=1:nwells
for i=1:nwells
    ts1 = DDN.SASDDN(DDN.CellID==OROP_CWF.CellID(i));
    for j=1:length(gridid)
        if ~OROP_ROI(i,j) || ~any(DDN.CellID==gridid(j)), continue; end
        ts2 = DDN.SASDDN(DDN.CellID==gridid(j));
        rsq = corrcoef([ts1,ts2]);
        if isnan(rsq(2,2))
            OROP_CORR(i,j) = 0.;
        else
            OROP_CORR(i,j) = max(0.,rsq(1,2));
        end
    end
end

% determine max corr coeff by wellfield
[OROP_CORR_wf,WFCode] = grpstats(OROP_CORR,{OROP_CWF.WFCode},["max","gname"]);

% create a table to write to CSV file
t_OROP_CORR= array2table([gridid,max(OROP_CORR)',OROP_CORR',OROP_CORR_wf'],...
    'VariableNames',[{'GRIDID','CWF'},OROP_CWF.WellName',WFCode']);
writetable(t_OROP_CORR,'OROP_CORR.csv');

