d_cur = pwd;
d_figs = fullfile(d_cur,'task3_3_plots');
save2pdf = 4;
saved_fname = 'task3_3_saved.mat';
d_shapefile = '/Volumes/Mac_xSSD/Shapefiles';
mlstd_color = lines(7);

% defind RA subregion start and end dates
RA_first6yr = datetime({'10/01/2007' '09/30/2013'});
RA_last6yr = datetime({'10/01/2013' '09/30/2019'});
RA_extended = datetime({'10/01/2019' '09/30/2023'});
RA_region = [RA_first6yr;RA_last6yr;RA_extended];

load(saved_fname);

%% Plot Average Rainfall
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
% for j=1:length(colname)
j = 3;
    symbolspec = makesymbolspec("Polygon",...
        {colname{j},[min_val max_val],'FaceColor',cmap},...
        {'Default','LineStyle','-','LineWidth',0.25,'FaceColor','w'});

    % [~,a] = create1x1Axes(ptitle{j});
    figure(1);
    clf;
    colormap(cmap);
    h = mapshow(g_intbbasin,'SymbolSpec',symbolspec);
    for i=1:length(h.Children)
        h.Children(i).EdgeColor = h.Children(i).FaceColor;
    end
    cb4 = colorbar('eastoutside','Ticks',(0:.1:1)*max_color,...
        'TickLabels',arrayfun(@(y) sprintf('%d',y),min_val:2:max_val,...
            'UniformOutput',false));
    cb4.Label.String = 'Rainfall, inch';

%     export2fig(d_figs,sprintf('avgrain_%d',j),save2pdf);
% end
shapewrite(g_intbbasin,fullfile(d_shapefile,sprintf('task3_3_rainfall_%d',j)));

%% Plot DDN map
% Max, median and mean of SAS DDN
max_sasddn = [max(-ddn)',max(-ddn1)',max(-ddn2)',max(-ddn3)'];
med_sasddn = [median(-ddn)',median(-ddn1)',median(-ddn2)',median(-ddn3)'];
avg_sasddn = [mean(-ddn)',mean(-ddn1)',mean(-ddn2)',mean(-ddn3)'];
sasddn = [max_sasddn,med_sasddn,avg_sasddn];

aggregate = {'Maximum','Median','Average'};
sasddn = reshape(sasddn,length(max_sasddn),size(max_sasddn,2),length(aggregate));

gridid = [g_grid_centroid.GRIDID]';
i_cellid = arrayfun(@(y) find(y==gridid),cellid);
for i=setdiff(1:length(gridid),i_cellid),g_grid_centroid(i).DDN = 0.; end

max_color = 15; 
alphaValue = 0.6;

% for k=1:size(sasddn,3)
k = 2;
% for j=1:size(sasddn,2)
j = 3;
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
    
    % [~,a] = create1x1Axes(ptitle);
    colormap(cmap);

    [h1,cb1] = plot1contour(g_grid_centroid,[0 max_color]);
    h1.FaceAlpha = alphaValue;
    cb1.Label.String = 'Drawdown, ft';
    cb1.FontSize = 9;

    mapshow(g_coastline,'Color',[0 0.65 0.9]);
    mapshow(g_wellfield,'FaceAlpha',0.0,'LineWidth',2,'EdgeColor',[.7 .7 .7]);
    mapshow(g_county,'Color','k','LineWidth',0.5);
    % h = mapshow(g_tbw_pwell,'Color','k','LineWidth',0.25,'Marker','o',...
    %     'MarkerSize',3,'MarkerFaceColor',[0 .5 0],...
    %     'MarkerEdgeColor',[0 .5 0]);
    xlabel('Easting'); ylabel('Northing');
    xlim([g_cwup_extend.X(1) g_cwup_extend.X(3)]);
    ylim([g_cwup_extend.Y(1) g_cwup_extend.Y(3)]);

    drawnow;
    cdata =cb1.Face.Texture.CData;
    cdata(end,:) = uint8(alphaValue*cdata(end,:));
    cd.Face.Texture.ColorType = 'truecoloralpha';
    cd.Face.Texture.CData = cdata;

    % export2fig(d_figs,sprintf([aggregate{k} 'DDN_%d'],j),save2pdf);
% end
% end
shapewrite(g_grid_centroid,fullfile(d_shapefile,sprintf('task3_3_DDN_%d',j)));

%% Plot Pumpage
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

% Compute pumpage coefficient of variation
i_period = (WklyPmp.WeekStartDate>=RA_last6yr(1)) & (WklyPmp.WeekStartDate<=RA_last6yr(2));
WklyPmp_RA3 = WklyPmp(i_period,{'PointName','WeeklyPumpage'});
temp = groupsummary(WklyPmp_RA3,'PointName',{'mean','std'},'WeeklyPumpage');
temp.mean_WeeklyPumpage(temp.mean_WeeklyPumpage==0) = 1e-6;
temp.coffvar = temp.std_WeeklyPumpage./temp.mean_WeeklyPumpage;
temp1 = [temp.PointName];
i_temp = cellfun(@(y) find(strcmp(y,temp1)),RA_WklyAvgPmp.PointName);
temp1 = temp(i_temp,:);
for i=1:length(i_pwell), g_tbw_pwell(i_pwell(i)).CoeffVar = temp1.coffvar(i); end
for i=1:length(i_pwell), g_tbw_pwell(i_pwell(i)).Stdev = temp1.std_WeeklyPumpage(i); end

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
% for j=1:length(colname)
j = 3;
    symbolspec = makesymbolspec("Point",...
        {colname{j},[0 max_pmp],'MarkerFaceColor',cmap},...
        {colname{j},0,'MarkerSize',2},...
        {colname{j},[0.0 .5],'MarkerSize',4},...
        {colname{j},[0.5 1.],'MarkerSize',6},...
        {colname{j},[1.0 1.5],'MarkerSize',8},...
        {colname{j},[1.5 2.],'MarkerSize',10},...
        {colname{j},[2.0 max_pmp],'MarkerSize',12},...
        {'Default','Marker','o','MarkerSize',2,'MarkerEdgeColor','k'});

    % colormap(cmap);
    h2 = mapshow(g_ra_avgpmp,'SymbolSpec',symbolspec);
    cb2 = colorbar('south','Ticks',0:(max_color/(max_pmp/0.5)):max_color,...
        'TickLabels',arrayfun(@(y) sprintf('%.1f',y),0:0.5:max_pmp,'UniformOutput',false));
    cb2.Label.String = 'Pumpage, mgd';
    cb2.Location = 'southoutside';
    
%     export2fig(d_figs,sprintf('avg_pumpage_%d',j),save2pdf);
% end

shapewrite(g_ra_avgpmp,fullfile(d_shapefile,sprintf('task3_3_avgpmp_%d',j)));

%% Plot OROP wells - deviation from target
i_targWL = cellfun(@(y) ~isempty(y),(strfind(sqlselect,', TargetWL,')));
temp = sql_results(i_targWL).Data;
% Remove unwanted well
targWL = temp(~strcmp(temp.PointName,'WRW-s'),:);

i_targDev = cellfun(@(y) ~isempty(y),(strfind(sqlselect,', Deviation,')));
i_notnull = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'IS NOT NULL')));
targDev = sql_results(i_targDev & i_notnull).Data;
targDev.WeekStartDate = datetime(targDev.WeekStartDate);

i_period = targDev.WeekStartDate<RA_extended(1);
targWL.RApor_med = cellfun(@(y) ...
    median(targDev(strcmp(targDev.PointName,y)&i_period,:).Deviation),...
    targWL.PointName,'UniformOutput',true);
i_period = targDev.WeekStartDate<RA_last6yr(1);
targWL.first6yrs_med = cellfun(@(y) ...
    median(targDev(strcmp(targDev.PointName,y)&i_period,:).Deviation),...
    targWL.PointName,'UniformOutput',true);
i_period = targDev.WeekStartDate>=RA_last6yr(1) & targDev.WeekStartDate<=RA_last6yr(2);
targWL.last6yrs_med = cellfun(@(y) ...
    median(targDev(strcmp(targDev.PointName,y)&i_period,:).Deviation),...
    targWL.PointName,'UniformOutput',true);
% Compute Target Offset variance
targWL.last6yrs_std = cellfun(@(y) ...
    std(targDev(strcmp(targDev.PointName,y)&i_period,:).Deviation),...
    targWL.PointName,'UniformOutput',true);
targWL.last6yrs_mean = cellfun(@(y) ...
    mean(targDev(strcmp(targDev.PointName,y)&i_period,:).Deviation),...
    targWL.PointName,'UniformOutput',true);
targWL.last6yrs_cv = targWL.last6yrs_std./targWL.last6yrs_mean;

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

i_oropwell = cellfun(@(y) find(strcmp(y,{g_temp.OROP_SASwell})),...
    targWL.PointName);
for i=1:length(i_oropwell)
    g_temp(i_oropwell(i)).TargetWL = targWL.TargetWL(i);
    g_temp(i_oropwell(i)).RApor_med = -targWL.RApor_med(i);
    g_temp(i_oropwell(i)).first6yrs_med = -targWL.first6yrs_med(i);
    g_temp(i_oropwell(i)).last6yrs_med = -targWL.last6yrs_med(i);
    g_temp(i_oropwell(i)).extyrs_med = -targWL.extyrs_med(i);
    g_temp(i_oropwell(i)).last6yrs_std = targWL.last6yrs_std(i);
    g_temp(i_oropwell(i)).last6yrs_mean = -targWL.last6yrs_mean(i);
    g_temp(i_oropwell(i)).last6yrs_cv = -targWL.last6yrs_cv(i);
end
g_temp = g_temp(cellfun(@(y) ~isempty(y),{g_temp.RApor_med}));

min_val = -5; max_val = 5;
max_color = max_val-min_val;
% cmap = flip(jet(max_color+max_val));
cmap = jet(max_color+max_val); cmap(1,:) = [1 1 1];
cmap = cmap(1:max_color,:);
colname = {'RApor_med';'first6yrs_med';'last6yrs_med';'extyrs_med'};
ptitle = {...
    'Median Target Deviation During 12-Year Recovery Period';...
    'Median Target Deviation First 6-Year Recovery Period';...
    'Median Target Deviation Last 6-Year Recovery Period';
    'Median Target Deviation Extended Recovery Period';
    };
% for j=1:length(colname)
j = 3;
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
        {'Default','Marker','s','MarkerSize',2,'MarkerEdgeColor','k'});

    % [~,a] = create1x1Axes(ptitle{j});
    % colormap(cmap);
    h3 = mapshow(g_temp,'SymbolSpec',symbolspec);

    temp = unique([symbolspec.MarkerSize{1:end-1,2}]);
    cb3 = colorbar('south','Ticks',temp-min_val,...
        'TickLabels',arrayfun(@(y) sprintf('%d',y),temp,'UniformOutput',false));
    cb3.Label.String = 'Target Offset, ft';
    cb3.Location = 'southoutside';
    for i=1:length(h3.Children)
        h3.Children(i).UserData = {...
            ['Well Name: ' g_temp(i).OROP_SASwell];
            ['Target Dev: ' sprintf('%.3f',g_temp(i).(colname{j}))]
        };
        h3.Children(i).DisplayName = g_temp(i).OROP_SASwell;
    end
    hf = gcf;
    set(datacursormode(hf),'UpdateFcn',@customDataTipCallBack); 

%     export2fig(d_figs,sprintf('medTargDev_%d',j),save2pdf);
% end

shapewrite(g_temp,fullfile(d_shapefile,sprintf('task3_3_oropwell_%d',j)));

%% Additional table for correlation plots
conn = odbc('MWP_CWF','SA',getenv('SA_PASSWORD'));
sql = [...
'select A.*,B.sumpp ',...
'from ( ',...
'    select  ',...
'        CASE WHEN WFCode=''MBR'' THEN ''MRB'' ELSE  ',...
'            CASE WHEN WFCode=''ELW'' THEN ''EDW'' ELSE  ',...
'            CASE WHEN WFCode=''NOP'' THEN ''NPC'' ELSE  ',...
'            CASE WHEN WFCode=''SOP'' THEN ''SPC'' ELSE  ',...
'                WFCode ',...
'            END ',...
'            END ',...
'            END ',...
'        END OROP_WFCode ',...
'        , WeekStartDate, AVG(WeeklyWaterlevel) avgwl, AVG(RLO) avgrlo ',...
'    from ( ',...
'        select WFCode ',...
'        ,WeekStartDate,WeeklyWaterlevel,WeeklyWaterlevel-TargetWL RLO ',...
'        from [dbo].[RA_SAS_WeeklyWL] A ',...
'        inner join [dbo].[RA_TargetWL] B on A.PointName=B.PointName ',...
'    ) X ',...
'    group by WFCode,WeekStartDate ',...
') A inner join ( ',...
'    select OROP_WFCode,WeekStartDate,sum(WeeklyPumpage) sumpp ',...
'    from [dbo].[RA_WeeklyPumpage] ',...
'    group by OROP_WFCode,WeekStartDate ',...
') B on A.OROP_WFCode=B.OROP_WFCode and A.WeekStartDate=B.WeekStartDate ',...
'where A.WeekStartDate between ''10/1/2013'' and ''9/30/2019'' ',...
'order by A.OROP_WFCode,A.WeekStartDate ' ...
    ];
Temp = fetch(conn,sql);
Temp.WeekStartDate = datetime(Temp.WeekStartDate);

clf;
h = gscatter(Temp.WeekStartDate,Temp.avgwl,Temp.OROP_WFCode,...
    lines(12),'..++xxss^^vv');

% clf;
% h = gscatter(Temp.WeekStartDate,Temp.avgrlo,Temp.OROP_WFCode,...
%     lines(12),'..++xxss^^vv'));
grid on;
xlabel('Date');
ylabel('OROP Waterlevel, ft NGVD');
set(h,'LineStyle','-');
set(h,'MarkerSize',4);

clf;
h = gscatter(Temp.sumpp,Temp.avgrlo,Temp.OROP_WFCode,...
    lines(12),'..++xxss^^vv');
grid on;
xlabel('Wellfield Pumpage, mgd');
ylabel('OROP RLO, ft');
set(h,'MarkerSize',4);

clf
groups = unique(Temp.OROP_WFCode);
colors = lines(12);
markers = 'ooosss^^^vvv';
for k=1:length(groups)
    T = Temp(strcmp(Temp.OROP_WFCode,groups{k}),:);
    h(k) = scatter3(T,'WeekStartDate','sumpp','avgwl','filled', ...
        'Marker',markers(k));
    % set(h(k),'MarkerSize',4);
    set(h(k),'MarkerFaceColor',colors(k,:));
    hold on;
end