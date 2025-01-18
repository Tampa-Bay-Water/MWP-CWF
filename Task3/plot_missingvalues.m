function plot_missingvalues(ax,d_figs,t_minwl,t_watlev,RA_region,save2pdf,layname)
layname = upper(layname);
if strcmpi(layname,'UFAS')
    t_watlev = renamevars(t_watlev,{'DailyWaterlevel'},{'Value'});
end
nwells = height(t_minwl);

% missing (null) value
t_watlev.missing = NaN(size(t_watlev.Value));
t_watlev.missing(isnan(t_watlev.Value)) = true;
for i=1:nwells
    wname = t_minwl.PointName{i};
    j = strcmp(t_watlev.PointName,wname);
    t_watlev.missing(j) = t_watlev.missing(j)*i;
end
ax.YAxis.FontSize = 9;
h = plot(t_watlev.TSTAMP,t_watlev.missing,...
    'o','MarkerSize',1);
hold on;
xr = xregion(RA_region);
set(xr(1:3:end),'FaceColor','y');
set(xr(2:3:end),'FaceColor','c');
set(xr(3:3:end),'FaceColor',[.5 .5 .5]);
for l=1:3, xr(l).FaceAlpha = 0.20; end
hold off;
grid on;
xlabel('Date'); ylabel('Well Name');
ylim([0 nwells+1]);
ax.YTick = 1:nwells;
ax.YTickLabel = t_minwl.PointName;
export2fig(d_figs,[layname 'wl_missing_data'],save2pdf);