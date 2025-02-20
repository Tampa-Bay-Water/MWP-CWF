function Fix_Figure3D
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

wnames = {'Cosme-20s','EW-11s','Jacksn26As','StPt-47s','EW-SM-15','CWD-Elem-SAS'};
wnstr = "'Cosme-20s','EW-11s','Jacksn26As','StPt-47s','EW-SM-15','CWD-Elem-SAS'";
conn = odbc('MWP_CWF','SA',getenv('SA_PASSWORD'));
temp = exec([
        'SELECT A.[PointName], A.[WeekStartDate] ',
        '    , A.WeeklyWaterlevel ',
        '    , [OneYr_MVMED] ',
        '    , [EightYr_MVMED] ',
        '    , C.TargetWL ',
        '    , case when A.[WeekStartDate] between ''10/01/2007'' and ''09/30/2013'' then ''RA_1stSixYrs'' ',
        '        else case when A.[WeekStartDate] between ''10/01/2013'' and ''09/30/2019'' then ''RA_2ndSixYrs'' ',
        '            else case when A.[WeekStartDate] between ''10/01/2019'' and ''09/30/2023'' then ''RA_Extended'' ',
        '                else NULL ',
        'end end end RA_Period ',
        'FROM [dbo].[RA_SAS_WeeklyWL] A ',
        'inner join [dbo].[RA_SAS_WeeklyWL_MVMED] B  ',
        '    ON A.PointName=B.PointName AND A.WeekStartDate=B.WeekStartDate ',
        'LEFT JOIN [dbo].[RA_TargetWL] C on A.PointName=C.PointName ',
        'where A.PointName in (' wnstr ') ',
        'ORDER BY A.PointName,A.WeekStartDate '], conn);



i_targDev = cellfun(@(y) ~isempty(y),(strfind(sqlselect,', Deviation,')));
i_notnull = cellfun(@(y) ~isempty(y),(strfind(sqlselect,'IS NOT NULL')));
targDev = sql_results(i_targDev & i_notnull).Data;
targDev.WeekStartDate = datetime(targDev.WeekStartDate);


plotwl_hydrograph('Figure 3D',...
    d_figs,targWL,targDev,RA_region,save2pdf,'sas');


function plotwl_hydrograph(ptitle,d_figs,t_minwl,t_watlev,RA_region,save2pdf,layname)
layname = upper(layname);
if strcmpi(layname,'SAS')
    t_minwl = renamevars(t_minwl,{'TargetWL'},{'AvgMin'});
end
nwells = height(t_minwl);

for i=1:nwells
    if mod((i-1),6)==0
        [~,a] = create3x2Axes_row({ptitle,'Recovery Assessment Period (WY 2008-2019)'});
    end
    
    j = mod((i-1),6)+1;
    subplot(a(1,j));
    gca.FontSize = 5;
    wname = t_minwl.PointName(i);
    targ = t_minwl.AvgMin(strcmp(t_minwl.PointName,wname));
    %temp = t_watlev(strcmp(t_watlev.PointName,wname),{'WeekStartDate','WklyWL','Deviation'});
    temp = t_watlev(strcmp(t_watlev.PointName,wname),{'WeekStartDate','WeeklyWaterlevel','Deviation_MAVG'});
    plot_wl1(temp,targ,wname,RA_region,layname);

    if i==nwells && j<6
        set(a(1,(j+1):6),'XColor',[1 1 1],'YColor',[1 1 1]);
        % delete(a(1,(j+1):6))
    end
    if j==6 || i==nwells
        sprintf('%sTargetDev_%02d',layname,int32(i/6))
        % export2fig(d_figs,sprintf('%sTargetDev_%02d',layname,int32(i/6)),save2pdf);
    end
end

%% single hydrograph
function plot_wl1(temp,targ,wname,RA_region,layname)
sdate = RA_region(1,1);
i_date = temp.WeekStartDate>=sdate;
yyaxis left
p1 = plot(temp.WeekStartDate(i_date),temp.WeeklyWaterlevel(i_date));
ylabel('Waterlevel, ft NGVD');
hold on
p2 = plot([sdate;temp.WeekStartDate(end)],[targ;targ],'-r');

yyaxis right
p3 = plot(temp.WeekStartDate(i_date),temp.Deviation_MAVG(i_date));
p4 = plot([sdate;temp.WeekStartDate(end)],[0;0]);
ylabel('Target Deviation, ft');
if strcmpi(layname,'SAS')
    ylim([-10,5]);
else
    ylim([-10,35]);
end
hold off

xr = xregion(RA_region);
set(xr(1:3:end),'FaceColor','y');
set(xr(2:3:end),'FaceColor','c');
set(xr(3:3:end),'FaceColor',[.5 .5 .5]);
for l=1:3, xr(l).FaceAlpha = 0.20; end

grid on;
xlabel('Date');
legend([p1,p2,p3,p4],...
    {'Weekly WL','Target Level','MAVG Deviation','Zero Deviation'},...
    'location','SouthEast','FontSize',4);
title(wname);
