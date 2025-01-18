%% MWP: CWF Feasibilty - Task 3.3 Analysis
%% 
% Set up directories

d_cur = pwd;
d_figs = fullfile(d_cur,'task3_3_plots');
save2pdf = 4;
saved_fname = 'task3_3_saved.mat';
mlstd_color = lines(7);

% defind RA subregion start and end dates
RA_first6yr = datetime({'10/01/2007' '09/30/2013'});
RA_last6yr = datetime({'10/01/2013' '09/30/2019'});
RA_extended = datetime({'10/01/2019' '09/30/2023'});
RA_region = [RA_first6yr;RA_last6yr;RA_extended];
%% Load Data 
% Get pumpage and waterlevel data by executing SQL file

if isfile(saved_fname)
    load(saved_fname,"sql_results");
else
    if ispc
        dv = 'SQL Server Native Client 11.0';
        sv = 'vgridfs';
        conn = database(['Driver=' dv ';Server=' sv ';Database=OROP_Data2' ...
	        ';Trusted_Connection=Yes;LoginTimeout=300;']);
        d_urm = 'F:\URM_old\Surm_All_Cells';
        d_shapefile = 'F:\IHM\shapefiles';
    end 
    if ismac
        conn = odbc('MWP_CWF','SA',getenv('SA_PASSWORD'));
        d_urm = '/Volumes/Mac_xSSD/oldURM';
        d_shapefile = '/Volumes/Mac_xSSD/Shapefiles';
    end
    sql_results = executeSQLScript(conn,'task3_3_matlab1.sql');
end
sqlselect = {sql_results.SQLQuery}';
i_wklypmp = cellfun(@(y) ~isempty(y),(strfind(sqlselect,', WeeklyPumpage,')));
WklyPmp = sql_results(i_wklypmp).Data;

i_weekly = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'WeekStartDate')));
i_monthly = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'MonthStartDate')));
i_cwf_total = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'cwf_total')));
CWF_WklyPmp = sql_results(i_weekly & i_cwf_total).Data;
CWF_WklyPmp.WeekStartDate = datetime(CWF_WklyPmp.WeekStartDate);

CWF_MnlyPmp = sql_results(i_monthly & i_cwf_total).Data;
CWF_MnlyPmp.MonthStartDate = datetime(CWF_MnlyPmp.MonthStartDate);
% Get geographical data from shapefiles

if isfile(saved_fname)
    load(saved_fname,"-regexp","^g_");
else
    g_coastline = shaperead(fullfile(d_shapefile,"INTBcoastline.shp"));
    g_wellfield = shaperead(fullfile(d_shapefile,"INTBwellfield.shp"));
    g_county = shaperead(fullfile(d_shapefile,"INTBcounty.shp"));
    g_cwup_extend = shaperead(fullfile(d_shapefile,"CWUP_extend.shp"));
    g_grid_centroid = shaperead(fullfile(d_shapefile,"INTBgrid_centroid.shp"));
    % g_grid = shaperead(fullfile(d_shapefile,"INTBgrid.shp"));
    g_oropwells = shaperead(fullfile(d_shapefile,"OROP_SASwells.shp"));
    g_intbbasin = shaperead(fullfile(d_shapefile,"INTB_Basins.shp"));
    
    g_tbw_pwell = shaperead("TBWProductionWells_FullListUTM08202019.shp");
    % fix two missing INTB_Model number
    g_tbw_pwell(strcmp('BUD 5R',{g_tbw_pwell.WellName})).INTB_Model = 21926;
    g_tbw_pwell(strcmp('BUD 6R',{g_tbw_pwell.WellName})).INTB_Model = 21925;
    % g_tbw_pwell(find(strcmp('BUD 5R',{g_tbw_pwell.WellName}))).INTB_Model = 21926;
    % g_tbw_pwell(find(strcmp('BUD 6R',{g_tbw_pwell.WellName}))).INTB_Model = 21925;

end
%% Pumpage Data Visualization
% Plot weekly and monthly pumpages

[~,a] = create2x1Axes({'CWF Pumpage for Recovery Assessment Period',...
    'Shaded Areas are Recovery Assessment subperiods of First 6-year, Last 6-year and Extended'});

subplot(a(1));
plot(datetime(CWF_WklyPmp.WeekStartDate),CWF_WklyPmp.cwf_mavg);
hold on
plot(datetime(CWF_WklyPmp.WeekStartDate),CWF_WklyPmp.cwf_total);
xr = xregion(RA_region);
set(xr(1:3:end),'FaceColor','y');
set(xr(2:3:end),'FaceColor','c');
set(xr(3:3:end),'FaceColor',[.5 .5 .5]);
for l=1:3, xr(l).FaceAlpha = 0.20; end
hold off
grid on;
xlabel('Date');
ylabel('Pumpage, mgd');
legend('Weekly Pumpage','52-week Mavg');

subplot(a(2));
plot(datetime(CWF_MnlyPmp.MonthStartDate),CWF_MnlyPmp.cwf_mavg);
hold on
plot(datetime(CWF_MnlyPmp.MonthStartDate),CWF_MnlyPmp.cwf_total);
xr = xregion(RA_region);
set(xr(1:3:end),'FaceColor','y');
set(xr(2:3:end),'FaceColor','c');
set(xr(3:3:end),'FaceColor',[.5 .5 .5]);
for l=1:3, xr(l).FaceAlpha = 0.20; end
hold off
grid on;
xlabel('Date');
ylabel('Pumpage, mgd');
legend('Monthly Pumpage','12-month Mavg');

export2fig(d_figs,'CWF_pumpage',save2pdf);
% Compute drawdowns using URM
% Weekly historical pumping during Recover Assessment Period (WY 2008-2019)

startdate_2nd = RA_last6yr(1);
startdate_ext = RA_extended(1);
tstamp = unique(WklyPmp.WeekStartDate);
ra_pwell = unique(WklyPmp.PointName);
% Period of original RA
i_period = tstamp<startdate_ext;
% first 6 years
i_period1 = tstamp<startdate_2nd;
tstamp1 = tstamp(i_period1);
% last 6 years
i_period2 = (tstamp>=startdate_2nd) & (tstamp<startdate_ext);
tstamp2 = tstamp(i_period2);
% extended period to WY2023
i_period3 = tstamp>=startdate_ext;
tstamp3 = tstamp(i_period3);
tstamp = tstamp(i_period);

% compute DDN -convoluted integral
if isfile(saved_fname)
    load(saved_fname,"cellid","ddn","ddn1","ddn2","ddn3");
else
    Surm = load(fullfile(d_urm,'Surm15_SAS73.mat'));
    Surm = Surm.Surm;
    %{
    i_pwell = ismember(ra_pwell,{Surm.URM.PWellCode});
    pwell_exclude = a_pwell(~i_pwell)
    %}
    cellid = Surm.CellID;
    ddn = zeros(length(tstamp)+length(Surm.TimeStep)-1,length(cellid));
    ddn1 = zeros(length(tstamp1)+length(Surm.TimeStep)-1,length(cellid));
    ddn2 = zeros(length(tstamp2)+length(Surm.TimeStep)-1,length(cellid));
    ddn3 = zeros(length(tstamp3)+length(Surm.TimeStep)-1,length(cellid));
    urm_pwell = arrayfun(@(y) Surm.URM(y).PWellCode,...
        1:length(Surm.URM),'UniformOutput',false);
    urm_wkno = (1:length(Surm.TimeStep))'; 
    sasurm = arrayfun(@(y) ...
        full(reshape(Surm.URM(y).DDN,length(cellid),length(urm_wkno))),...
        1:length(Surm.URM),'UniformOutput',false)';
    for i=1:length(urm_pwell)
        i_pwell = strcmp(Surm.URM(i).PWellCode,WklyPmp.PointName);
        pumpage = WklyPmp.WeeklyPumpage(i_pwell);
        ddn = ddn+conv2(pumpage(i_period),sasurm{i}');
        ddn1 = ddn1+conv2(pumpage(i_period1),sasurm{i}');
        ddn2 = ddn2+conv2(pumpage(i_period2),sasurm{i}');
        ddn3 = ddn3+conv2(pumpage(i_period3),sasurm{i}');
    end
end
if ~isfile(saved_fname)
    save(saved_fname);
end

% save tables results
writetable(WklyPmp,'task3_3_result.xlsx','FileType','spreadsheet','Sheet','WklyPmp');
clear Surm WklyPmp
% Plot Max/Median/Mean drawdown by INTB cells

% Max, median and mean of SAS DDN
max_sasddn = [max(-ddn)',max(-ddn1)',max(-ddn2)',max(-ddn3)'];
med_sasddn = [median(-ddn)',median(-ddn1)',median(-ddn2)',median(-ddn3)'];
avg_sasddn = [mean(-ddn)',mean(-ddn1)',mean(-ddn2)',mean(-ddn3)'];
sasddn = [max_sasddn,med_sasddn,avg_sasddn];

% save tables results
writetable(...
    array2table([cellid,sasddn],...
    'VariableNames',{'CellID',...
        'MaxDDN_RApor','MaxDDN_first6yrs','MaxDDN_last6yrs','MaxDDN_extyrs',...
        'MedDDN_RApor','MedDDN_first6yrs','MedDDN_last6yrs','MedDDN_extyrs',...
        'AvgDDN_RApor','AvgDDN_first6yrs','AvgDDN_last6yrs','AvgDDN_extyrs'}),...
    'task3_3_result.xlsx','FileType','spreadsheet','Sheet','DDN_RA_por');
clear ddn ddn1 ddn2 ddn3

aggregate = {'Maximum','Median','Average'};
sasddn = reshape(sasddn,length(max_sasddn),size(max_sasddn,2),length(aggregate));

% plot DDN
gridid = [g_grid_centroid.GRIDID]';
i_cellid = arrayfun(@(y) find(y==gridid),cellid);
for i=setdiff(1:length(gridid),i_cellid),g_grid_centroid(i).DDN = 0.;end
%{
gridid = [g_grid.GRIDID]';
i_cellid = arrayfun(@(y) find(y==gridid),cellid);
%}
max_color = 15; 
alphaValue = 0.6;

for k=1:size(sasddn,3)
for j=1:size(sasddn,2)
    if k>1, max_color = 10; end
    cmap = jet(max_color); cmap(1,:) = [1 1 1];

    switch j
        case 1
            for i=1:length(cellid), g_grid_centroid(i_cellid(i)).DDN = sasddn(i,j,k); end
            ptitle = [aggregate{k} ' DDN During 12-Year Recovery Period (URM-based)'];
        case 2
            for i=1:length(cellid), g_grid_centroid(i_cellid(i)).DDN = sasddn(i,j,k); end
            ptitle = [aggregate{k} ' DDN During First 6-Year Recovery Period (URM-based)'];
        case 3
            for i=1:length(cellid), g_grid_centroid(i_cellid(i)).DDN = sasddn(i,j,k); end
            ptitle = [aggregate{k} ' DDN During Last 6-Year Recovery Period (URM-based)'];
        case 4
            for i=1:length(cellid), g_grid_centroid(i_cellid(i)).DDN = sasddn(i,j,k); end
            ptitle = [aggregate{k} ' DDN During the Extended Recovery Period (URM-based)'];
    end
    
    [~,a] = create1x1Axes(ptitle);
    colormap(cmap);

    [h,cb] = plot1contour(g_grid_centroid,[0 max_color]);
    % h.FaceAlpha = alphaValue;
    cb.Label.String = 'Drawdown, ft';

    mapshow(g_coastline,'Color',[0 0.65 0.9]);
    mapshow(g_wellfield,'FaceAlpha',0.0,'LineWidth',2,'EdgeColor',[.7 .7 .7]);
    mapshow(g_county,'Color','k','LineWidth',0.5);
    % h = mapshow(g_tbw_pwell,'Color','k','LineWidth',0.25,'Marker','o',...
    %     'MarkerSize',3,'MarkerFaceColor',[0 .5 0],...
    %     'MarkerEdgeColor',[0 .5 0]);
    xlabel('Easting'); ylabel('Northing');
    xlim([g_cwup_extend.X(1) g_cwup_extend.X(3)]);
    ylim([g_cwup_extend.Y(1) g_cwup_extend.Y(3)]);

    % drawnow;
    % cdata =cb.Face.Texture.CData;
    % cdata(end,:) = uint8(alphaValue*cdata(end,:));
    % cd.Face.Texture.ColorType = 'truecoloralpha';
    % cd.Face.Texture.CData = cdata;

    export2fig(d_figs,sprintf([aggregate{k} 'DDN_%d'],j),save2pdf);
end
end

clear g_grid g_grid_centroid cellid gridid % X Y
clear max_sasddn med_sasddn avg_sasddn sasddn sasurm 
%}
% Plot average pumpage


i_ra_avg = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'RA_AVG,')));
RA_WklyAvgPmp = sql_results(i_ra_avg).Data;
i_pwell = arrayfun(@(y) find(y==[g_tbw_pwell.INTB_Model]),...
    RA_WklyAvgPmp.WithdrawalPointID,'UniformOutput',false);
% remove two wells missing from shapefile
RA_WklyAvgPmp = RA_WklyAvgPmp(cellfun(@(y) ~isempty(y),i_pwell),:);
i_pwell = arrayfun(@(y) find(y==[g_tbw_pwell.INTB_Model]),...
    RA_WklyAvgPmp.WithdrawalPointID);
for i=1:length(i_pwell), g_tbw_pwell(i_pwell(i)).RA_AVG = RA_WklyAvgPmp.RA_AVG(i); end
for i=1:length(i_pwell), g_tbw_pwell(i_pwell(i)).RA_AVG1 = RA_WklyAvgPmp.RA_AVG1(i); end
for i=1:length(i_pwell), g_tbw_pwell(i_pwell(i)).RA_AVG2 = RA_WklyAvgPmp.RA_AVG2(i); end
for i=1:length(i_pwell), g_tbw_pwell(i_pwell(i)).RA_AVG3 = RA_WklyAvgPmp.RA_AVG3(i); end
g_ra_avgpmp = g_tbw_pwell(cellfun(@(y) ~isempty(y),{g_tbw_pwell.RA_AVG}));

max_color = 10;
max_pmp = 2.5;
cmap = jet(max_color); cmap(1,:) = [1 1 1];
colname = {'RA_AVG';'RA_AVG1';'RA_AVG2';'RA_AVG3'};
ptitle = {...
    'Average Pumpage During 12-Year Recovery Period';...
    'Average Pumpage During First 6-Year Recovery Period';...
    'Average Pumpage During Last 6-Year Recovery Period';
    'Average Pumpage During Extended Recovery Period';
    };
for j=1:length(colname)
    symbolspec = makesymbolspec("Point",...
        {colname{j},[0 max_pmp],'MarkerFaceColor',cmap},...
        {colname{j},0,'MarkerSize',2},...
        {colname{j},[0.0 .5],'MarkerSize',4},...
        {colname{j},[0.5 1.],'MarkerSize',6},...
        {colname{j},[1.0 1.5],'MarkerSize',8},...
        {colname{j},[1.5 2.],'MarkerSize',10},...
        {colname{j},[2.0 max_pmp],'MarkerSize',12},...
        {'Default','Marker','o','MarkerSize',2,'MarkerEdgeColor','k'});

    [~,a] = create1x1Axes(ptitle{j});
    colormap(cmap);
    mapshow(g_coastline,'Color',[0 0.65 0.9]);
    mapshow(g_wellfield,'FaceAlpha',0.0,'LineWidth',2,'EdgeColor',[.7 .7 .7]);
    mapshow(g_county,'Color','k','LineWidth',0.5);
    xlabel('Easting'); ylabel('Northing');
    xlim([g_cwup_extend.X(1) g_cwup_extend.X(3)]);
    ylim([g_cwup_extend.Y(1) g_cwup_extend.Y(3)]);

    mapshow(g_ra_avgpmp,'SymbolSpec',symbolspec);
    cb = colorbar('southoutside','Ticks',0:(1/(max_pmp/0.5)):1,...
        'TickLabels',arrayfun(@(y) sprintf('%.1f',y),0:0.5:max_pmp,'UniformOutput',false));
    cb.Label.String = 'Pumpage, mgd';
    
    export2fig(d_figs,sprintf('avg_pumpage_%d',j),save2pdf);
end
%% Waterlevel Data Visualization
% SAS target

i_targWL = cellfun(@(y) ~isempty(y),(strfind(sqlselect,', TargetWL,')));
temp = sql_results(i_targWL).Data;
% Remove unwanted well
targWL = temp(~strcmp(temp.PointName,'WRW-s'),:);

i_targDev = cellfun(@(y) ~isempty(y),(strfind(sqlselect,', Deviation,')));
i_notnull = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'IS NOT NULL')));
targDev = sql_results(i_targDev & i_notnull).Data;
targDev.WeekStartDate = datetime(targDev.WeekStartDate);

plotwl_hydrograph('Water Level and Target Deviation at OROP Wells',...
    d_figs,targWL,targDev,RA_region,save2pdf,'sas');
% Regulatory and SWIMAL permissible levels

i_rwellperm = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'RA_RegWellPermit')));
regwellPermit = sql_results(i_rwellperm).Data;

i_rwell = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'-AvgMin Deviation')));
regwellWL = sql_results(i_rwell).Data;
regwellWL.WeekStartDate = datetime(regwellWL.WeekStartDate);

plotwl_hydrograph('Water Level at Regulatory and SWIMAL Wells',...
    d_figs,regwellPermit,regwellWL,RA_region,save2pdf,'ufas');
%% Water level EDA
% Missing Values - SAS

i_saswl = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'dbo.RA_SAS_DailyWL')));
SAS_WL_All = sql_results(i_saswl).Data;
SAS_WL_All.TSTAMP = datetime(SAS_WL_All.TSTAMP);

[~,ax] = create1x1Axes('Missing Data for OROP Wells',true);
plot_missingvalues(ax,d_figs,targWL,SAS_WL_All,RA_region,save2pdf,'sas');
% Missing Values - UFAS

i_ufaswl = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'dbo.RA_UFAS_DailyWL')));
UFAS_WL_All = sql_results(i_ufaswl).Data;
UFAS_WL_All.TSTAMP = datetime(UFAS_WL_All.TSTAMP);

[~,ax] = create1x1Axes('Missing Data for Regulartory and SWIMAL Wells',true);
plot_missingvalues(ax,d_figs,regwellPermit,UFAS_WL_All,RA_region,save2pdf,'ufas');
% Histograms
% All data pulled from database

% statistical table

plot_wlhist(d_figs,targWL,SAS_WL_All(:,{'PointName','TSTAMP','Value'}),...
    RA_region,save2pdf,'sas');
plot_wlhist(d_figs,regwellPermit,UFAS_WL_All(:,{'PointName','TSTAMP','DailyWaterlevel'}),...
    RA_region,save2pdf,'ufas');

clear SAS_WL_All UFAS_WL_All
%% Compute Medians

i_period = targDev.WeekStartDate<RA_extended(1);
targWL.RApor_med = cellfun(@(y) ...
    median(targDev(strcmp(targDev.PointName,y)&i_period,:).Deviation),...
    targWL.PointName,'UniformOutput',true);
i_period = targDev.WeekStartDate<RA_last6yr(1);
targWL.first6yrs_med = cellfun(@(y) ...
    median(targDev(strcmp(targDev.PointName,y)&i_period,:).Deviation),...
    targWL.PointName,'UniformOutput',true);
i_period = targDev.WeekStartDate>=RA_last6yr(1);
targWL.last6yrs_med = cellfun(@(y) ...
    median(targDev(strcmp(targDev.PointName,y)&i_period,:).Deviation),...
    targWL.PointName,'UniformOutput',true);
i_period = targDev.WeekStartDate>=RA_extended(1);
targWL.extyrs_med = cellfun(@(y) ...
    median(targDev(strcmp(targDev.PointName,y)&i_period,:).Deviation),...
    targWL.PointName,'UniformOutput',true);

i_oropwell = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'OROP_SASwell')));
OROPwell = sql_results(i_oropwell).Data;
dczone = utmzone(mean(OROPwell.DDLatitude,'omitnan'),mean(-OROPwell.DDLongitude,'omitnan'));
utmstruct = defaultm('utm'); 
utmstruct.zone = dczone;  
utmstruct.geoid = wgs84Ellipsoid;
utmstruct = defaultm(utmstruct);
[OROPwell.X,OROPwell.Y] = projfwd(utmstruct,OROPwell.DDLatitude,-OROPwell.DDLongitude);
OROPwell.Geometry = repmat({'Point'},height(OROPwell),1);
g_temp = table2struct(...
    OROPwell(:,{'Geometry','X','Y',...
        'PointID','SiteID','CompositeTimeseriesID','OROP_SASwell','WellfieldCode'}));
% shapewrite(g_temp,fullfile(d_shapefile,'OROP_SASwells.shp'));
i_oropwell = cellfun(@(y) find(strcmp(y,{g_temp.OROP_SASwell})),...
    targWL.PointName);
for i=1:length(i_oropwell)
    g_temp(i_oropwell(i)).TargetWL = targWL.TargetWL(i);
    g_temp(i_oropwell(i)).RApor_med = targWL.RApor_med(i);
    g_temp(i_oropwell(i)).first6yrs_med = targWL.first6yrs_med(i);
    g_temp(i_oropwell(i)).last6yrs_med = targWL.last6yrs_med(i);
    g_temp(i_oropwell(i)).extyrs_med = targWL.extyrs_med(i);
end
g_temp = g_temp(cellfun(@(y) ~isempty(y),{g_temp.RApor_med}));

min_val = -5; max_val = 5;
max_color = max_val-min_val;
cmap = flip(jet(max_color+max_val));
cmap = cmap(1:max_color,:);
% cmap = hsv(max_color+100);
% cmap = cmap(20+(1:max_color),:);
colname = {'RApor_med';'first6yrs_med';'last6yrs_med';'extyrs_med'};
ptitle = {...
    'Median Target Deviation During 12-Year Recovery Period';...
    'Median Target Deviation First 6-Year Recovery Period';...
    'Median Target Deviation Last 6-Year Recovery Period';
    'Median Target Deviation Extended Recovery Period';
    };
for j=1:length(colname)
    symbolspec = makesymbolspec("Point",...
        {colname{j},[min_val max_val],'MarkerFaceColor',cmap},...
        {colname{j},[min_val -4.],'MarkerSize',3},...
        {colname{j},[-4 -3.],'MarkerSize',4},...
        {colname{j},[-3. -2.],'MarkerSize',6},...
        {colname{j},[-2. -1.],'MarkerSize',8},...
        {colname{j},[-1. 0.0],'MarkerSize',10},...
        {colname{j},[0.0 1.0],'MarkerSize',12},...
        {colname{j},[1.0 2.0],'MarkerSize',14},...
        {colname{j},[2.0 3.0],'MarkerSize',16},...
        {colname{j},[3.0 4.0],'MarkerSize',18},...
        {colname{j},[4.0 max_val],'MarkerSize',20},...
        {'Default','Marker','o','MarkerSize',2,'MarkerEdgeColor','k'});

    [~,a] = create1x1Axes(ptitle{j});
    colormap(cmap);
    mapshow(g_coastline,'Color',[0 0.65 0.9]);
    mapshow(g_wellfield,'FaceAlpha',0.0,'LineWidth',2,'EdgeColor',[.7 .7 .7]);
    mapshow(g_county,'Color','k','LineWidth',0.5);
    xlabel('Easting'); ylabel('Northing');
    xlim([g_cwup_extend.X(1) g_cwup_extend.X(3)]);
    ylim([g_cwup_extend.Y(1) g_cwup_extend.Y(3)]);

    h = mapshow(g_temp,'SymbolSpec',symbolspec);

    temp = unique([symbolspec.MarkerSize{1:end-1,2}]);
    cb = colorbar('southoutside','Ticks',...
        (temp-min_val)/(max_val-min_val),...
        'TickLabels',arrayfun(@(y) sprintf('%d',y),temp,'UniformOutput',false));
    cb.Label.String = 'Deviation, ft';
    for i=1:length(h.Children)
        h.Children(i).UserData = {...
            ['Well Name: ' g_temp(i).OROP_SASwell];
            ['Target Dev: ' sprintf('%.3f',g_temp(i).(colname{j}))]
        };
        h.Children(i).DisplayName = g_temp(i).OROP_SASwell;
    end
    hf = gcf;
    set(datacursormode(hf),'UpdateFcn',@customDataTipCallBack); 

    export2fig(d_figs,sprintf('medTargDev_%d',j),save2pdf);
end

% save tables results
writetable(targDev,'task3_3_result.xlsx','FileType','spreadsheet','Sheet','OROPwellWL');
writetable(regwellWL,'task3_3_result.xlsx','FileType','spreadsheet','Sheet','regwellWL');

clear targDev
%% Plot Average Annual Basin Rainfall

t_rain = readtable('RA_BayesBasinRain.xlsx','FileType','spreadsheet');
i_basin = arrayfun(@(y) find([g_intbbasin.CLASS]==y),t_rain.BasinID);
for i=1:length(i_basin), g_intbbasin(i_basin(i)).RA_POR = t_rain.RA_POR(i); end
for i=1:length(i_basin), g_intbbasin(i_basin(i)).RA_POR1 = t_rain.RA_POR1(i); end
for i=1:length(i_basin), g_intbbasin(i_basin(i)).RA_POR2 = t_rain.RA_POR2(i); end

max_color = 100;
min_val = 45; max_val = 65;
cmap = flip(jet(max_color));
colname = {'RA_POR';'RA_POR1';'RA_POR2'};
ptitle = {...
    'Average Annual Bayesian Basin Rain During 12-Year Recovery Period';...
    'Average Annual Bayesian Basin Rain First 6-Year Recovery Period';...
    'Average Annual Bayesian Basin Rain Last 6-Year Recovery Period';
    };
for j=1:length(colname)
    symbolspec = makesymbolspec("Polygon",...
        {colname{j},[min_val max_val],'FaceColor',cmap},...
        {'Default','LineStyle','-','LineWidth',0.25,'FaceColor','w'});

    [~,a] = create1x1Axes(ptitle{j});
    colormap(cmap);
    h = mapshow(g_intbbasin,'SymbolSpec',symbolspec);
    for i=1:length(h.Children)
        h.Children(i).EdgeColor = h.Children(i).FaceColor;
    end
    cb = colorbar('southoutside','Ticks',0:.1:1,...
        'TickLabels',arrayfun(@(y) sprintf('%d',y),min_val:2:max_val,...
            'UniformOutput',false));
    cb.Label.String = 'Rainfall, inch';

    mapshow(g_coastline,'Color',[0 0.65 0.9]);
    mapshow(g_wellfield,'FaceAlpha',0.0,'LineWidth',2,'EdgeColor',[.7 .7 .7]);
    mapshow(g_county,'Color','k','LineWidth',0.5);
    xlabel('Easting'); ylabel('Northing');
    xlim([g_cwup_extend.X(1) g_cwup_extend.X(3)]);
    ylim([g_cwup_extend.Y(1) g_cwup_extend.Y(3)]);

    export2fig(d_figs,sprintf('avgrain_%d',j),save2pdf);
end
%% Compare with long-term medians (6 & 8 years moving median)

i_mvmed = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'* FROM RA_SAS_WeeklyWL_MVMED')));
WklyWL_MvMed = sql_results(i_mvmed).Data;
WklyWL_MvMed.WeekStartDate = datetime(WklyWL_MvMed.WeekStartDate);

for i=1:height(targWL)
    if mod((i-1),6)==0
        [~,a] = create3x2Axes_row({'Water Level, Long-term Running Median and Target Deviation',...
            'Recovery Assessment Period (WY 2008-2019)'});
    end
    
    j = mod((i-1),6)+1;
    subplot(a(1,j));
    gca.FontSize = 5;
    wname = targWL.PointName(i);
    targ = targWL.TargetWL(strcmp(targWL.PointName,wname));
    temp = WklyWL_MvMed(strcmp(WklyWL_MvMed.PointName,wname),...
        {'WeekStartDate','SixYr_MVMED','EightYr_MVMED'});
    plot_wl2(temp,targ,wname,RA_first6yr(1),RA_region);

    if i==height(targWL) && j<6
        set(a(1,(j+1):6),'XColor',[1 1 1],'YColor',[1 1 1]);
        % delete(a(1,(j+1):6))
    end
    if j==6 || i==height(targWL)
        export2fig(d_figs,sprintf('MedianTargetDev_%02d',int32(i/6)),save2pdf);
    end
end

% save tables results
writetable(WklyWL_MvMed,'task3_3_result.xlsx','FileType','spreadsheet','Sheet','WL_MovingMedian');
clear WklyWL_MvMed
%% Analysis and Plots of Streamflow
% Daily Moving Average and Moving Median

i_flow = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'DailyFlow')));
DailyFLOW = sql_results(i_flow).Data;
DailyFLOW.DATE = datetime(DailyFLOW.DATE);

% permit threshold
i_flow = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'MinimumFlowTable')));
mfltab = sql_results(i_flow).Data;

ax_title = {...
    'One-year Moving Average','Five-year Moving Average','Ten-year Moving Average'};
p_title = {
    'By Annual Streamflow at the Hillsborough River near Morris Bridge';...
    'By Annual Streamflow at the Anclote River near Elfers';...
    'By Annual Streamflow at the Pithlachascotee River near New Port Richey' ...
    };
fname = {'DailyFlow_HillsAtMR','DailyFlow_AncAtELF','DailyFlow_CoteeAtNPR'};
staid = [6;22;24];
datname = {...
    'OneYrMvAvg','OneYrMvMed';...
    'FiveYrMvAvg','FiveYrMvMed';...
    'TenYrMvAvg','TenYrMvMed'};

for j=1:length(p_title)
    DlyFlow_BYID = DailyFLOW(DailyFLOW.FlowStationID==staid(j),:);
    perm = mfltab( ...
        mfltab.FlowStationID==staid(j)&strcmpi(mfltab.Tier,'Short-Term')&mfltab.BlockNum==0,...
        {'Type','Value'});
    loflow = perm.Value(strcmp(perm.Type,'LowFlow'));
    hiflow = perm.Value(strcmp(perm.Type,'HighFlow'));
    perm = cell2table({...
        DlyFlow_BYID.DATE(1),loflow,hiflow;DlyFlow_BYID.DATE(end),loflow,hiflow},...
        'VariableNames',{'Date','LowFlow','HighFlow'});
    
    % defind region of flow block (regime)
    years = unique(DlyFlow_BYID.Year);
    nyear = length(years);
    T1 = mfltab(strcmpi(mfltab.Type,'StartDate')&mfltab.BlockNum>0,:);
    T2 = mfltab(strcmpi(mfltab.Type,'EndDate')&mfltab.BlockNum>0,:);
    blk_region = [reshape(arrayfun(@(y,x) ...
        datetime([x,...
        T1{strcmp(T1.Tier,'Month'),'Value'}(y),...
        T1{strcmp(T1.Tier,'Day'),'Value'}(y)]),...
        repmat([1 3 2],nyear,1),repmat(years,1,3)),...'UniformOutput',false)',...
        1,nyear*3);
    reshape(arrayfun(@(y,x) ...
        datetime([x,...
        T2{strcmp(T2.Tier,'Month'),'Value'}(y),...
        T2{strcmp(T2.Tier,'Day'),'Value'}(y)+1]),...
        repmat([1 3 2],nyear,1),[years,years,years+1]),...'UniformOutput',false)',...
        1,nyear*3)];
    blk_region = sortrows(blk_region',1);

    % Plot daily flow and moving mean and median 
    [~,a] = create3x1Axes({p_title{j},...
        'POR 1/1/1989-12/31/2019 (shaded by MFL flow regime as block number)'},true,false);
    
    for i=1:3
        subplot(a(i));
        a(i).ColorOrder = mlstd_color([1 2 5 6],:);
        plot(DlyFlow_BYID.DATE,DlyFlow_BYID.Value);
        hold on;
        plot(DlyFlow_BYID.DATE,DlyFlow_BYID.(datname{i,1}));
        plot(DlyFlow_BYID.DATE,DlyFlow_BYID.(datname{i,2}),'Color',mlstd_color(4,:));
        plot(perm.Date,table2array(perm(:,{'LowFlow','HighFlow'})),'--k');
        xr = xregion(blk_region);
        hold off;
        set(xr(1:3:end),'FaceColor','r');
        set(xr(2:3:end),'FaceColor','c');
        set(xr(3:3:end),'FaceColor','y');
        for l=1:3, xr(l).FaceAlpha = 0.20; end
        a(i).YScale = 'log';
        grid on;
        xlabel('Date'); ylabel('Flow, cfs');
        legend({'Daily','Moving Mean','Moving Median','Permit'},...
            'Location','southeast','FontSize',7);
        title(ax_title{i})
    end
    export2fig(d_figs,fname{j},save2pdf);
end
% Long-term Statistics (5 and 10 years means and medians)

i_flow = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'FlowStats_MFL')));
FLOW_STATS = sql_results(i_flow).Data;
FLOW_STATS.StartDate = datetime(FLOW_STATS.StartDate);
FLOW_STATS.EndDate = datetime(FLOW_STATS.EndDate);

% permit threshold
i_flow = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'MinimumFlowTable')));
mfltab = sql_results(i_flow).Data;

ax_title = {...
    'No Flow Block (Annually)',...
    'Block 1 (April 20 to June 24)',...
    'Block 2 (October 28 to April 19)',...
    'Block 3 (June 25 to October 27)'; ...
    'No Flow Block (Annually)',...
    'Block 1 (April 12 to July 21)',...
    'Block 2 (October 15 to April 11)',...
    'Block 3 (July 22 to October 14)'; ...
    'No Flow Block (Annually)',...
    'Block 1 (April 25 to June 23)',...
    'Block 2 (October 17 to April 24)',...
    'Block 3 (June 24 to October 16)'; ...
    };
fname = {'MFL_LT_HillsAtMR','MFL_LT_AncAtELF','MFL_LT_CoteeAtNPR'};
% ylimits = [10 10000;1 10000;0.0100 10000];

for j=1:length(p_title)
    FLSTATS_BYID = FLOW_STATS(FLOW_STATS.FlowStationID==staid(j),:);
    mindate = min(FLSTATS_BYID.StartDate);
    maxdate = max(FLSTATS_BYID.EndDate);
    permit_flow = mfltab( ...
        strcmpi(mfltab.Tier,'Long-Term') & mfltab.FlowStationID==staid(j),...
        {'BlockNum','Type','Value'});
    
    [~,a] = create2x2Axes({p_title{j},...
        'POR 1/1/1989-12/31/2019 (shaded by RA subperiod)'},true);
    for i=1:4
        subplot(a(i));
        temp = FLSTATS_BYID(FLSTATS_BYID.BlockNum==i-1,{'EndDate','STATS_VAL','STATS_NAME'});
        perm = permit_flow(permit_flow.BlockNum==i-1,{'BlockNum','Value','Type'});
        gscatter(temp.EndDate,temp.STATS_VAL,temp.STATS_NAME,...
            mlstd_color([1 2 5 6],:),'osos','filled');
        hold on;
        a(i).ColorOrder = mlstd_color([1 2 5 6],:);
        for k=1:height(perm)
            plot([mindate;maxdate],[perm.Value(k);perm.Value(k)],'LineWidth',2);
        end
        xr = xregion(RA_region);
        set(xr(1:3:end),'FaceColor','y');
        set(xr(2:3:end),'FaceColor','c');
        set(xr(3:3:end),'FaceColor',[.5 .5 .5]);
        for l=1:3, xr(l).FaceAlpha = 0.20; end
        hold off;
        a(i).YScale = 'log';
        a(i).XLabel.String = 'Date';
        a(i).YLabel.String = 'Flow, cfs';
        % a(i).YLim = ylimits(j,:);
        % a(i).XLim = [mindate maxdate];
        grid(a(i),"on");
        legend({'FiveYrAVG','FiveYrMED','TenYrAVG','TenYrMED',...
            'MFL FiveYrAVG','MFL FiveYrMED','MFL TenYrAVG','MFL TenYrMED'},...
            'Location','southeast','FontSize',7);
        title(ax_title{j,i});
    end
    export2fig(d_figs,fname{j},save2pdf);
end

% save tables results
writetable(DailyFLOW(:,{'FlowStationID','DATE','Value','OneYrMvMed','FiveYrMvAvg','FiveYrMvMed','TenYrMvAvg','TenYrMvMed'}),...
    'task3_3_result.xlsx','FileType','spreadsheet','Sheet','DailyFlow_Hills');
clear DailyFLOW
% Zoom in the Flow Hydrographs to RA Period

fname = {'DailyFlow_HillsAtMR','DailyFlow_AncAtELF','DailyFlow_CoteeAtNPR',...
    'MFL_LT_HillsAtMR','MFL_LT_AncAtELF','MFL_LT_CoteeAtNPR'};
save2pdf = 6;

for j=1:length(fname)
    fig = openfig(fullfile(d_figs,fname{j}));
    a = get(fig,'Children');
    a = a(end:-2:2);
    set(a,'XLim',[datetime([2007,9,1]),datetime([2023,11,1])]);
    export2fig(d_figs,[fname{j} '_RA'],save2pdf);
end
%% Saved Result Tables in Excel File

% save tables results
writetable(CWF_MnlyPmp,'task3_3_result.xlsx','FileType','spreadsheet','Sheet','CWF_MnlyPmp');
writetable(CWF_WklyPmp,'task3_3_result.xlsx','FileType','spreadsheet','Sheet','CWF_WklyPmp');
writetable(RA_WklyAvgPmp,'task3_3_result.xlsx','FileType','spreadsheet','Sheet','RAWklyAvgPmp');
writetable(targWL,'task3_3_result.xlsx','FileType','spreadsheet','Sheet','targWL');
writetable(regwellPermit,'task3_3_result.xlsx','FileType','spreadsheet','Sheet','UFAS_avgmin');
writetable(FLOW_STATS,'task3_3_result.xlsx','FileType','spreadsheet','Sheet','BlockFlow_Hills');
writetable(t_stats,'task3_3_result.xlsx','FileType','spreadsheet','Sheet','DailyWL_stats');
%% Merge all pdf files

clear
% fig2pdf
%% Plotting functions

function plot_wl2(temp,targ,wname,sdate,RA_region)
i_date = temp.WeekStartDate>=sdate;
p1 = plot(temp.WeekStartDate(i_date),temp.SixYr_MVMED(i_date)-targ);
hold on
p2 = plot(temp.WeekStartDate(i_date),temp.EightYr_MVMED(i_date)-targ);
p3 = plot([sdate;temp.WeekStartDate(end)],[0;0],'-k');
ylabel('Target Deviation, ft');
ylim([-15,15]);
hold off

xr = xregion(RA_region);
set(xr(1:3:end),'FaceColor','y');
set(xr(2:3:end),'FaceColor','c');
set(xr(3:3:end),'FaceColor',[.5 .5 .5]);
for l=1:3, xr(l).FaceAlpha = 0.20; end

grid on;
xlabel('Date');
legend([p1,p2,p3],{'6yr-mvmed','8yr-mvmed','Zero Deviation'},...
    'location','SouthEast','FontSize',4);
title(wname);
end