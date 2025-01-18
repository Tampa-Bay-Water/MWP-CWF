function head_time_contour(headfile,tsteps,plotflag)
% contour overtime

if nargin < 3, plotflag = {'surface'}; end
if nargin < 2, tsteps = 1:216; end
if nargin < 1 || isempty(headfile)
    headfile = 'F:\IHM\INTB_Run401_Complete\Modflow\HeadMnly.BIN';
end
skip_tstep = 0;
sim_tstart = datenum('1/1/1989');
data_interval = 31;

% plot flag
pflagmap = {...
  'notuse',...  % 1 hydrographs
  'notuse',...  % 2 cross sections
  'notuse',...  % 3 multiwell contour
  'notuse',...  % 4 hydrograph with waterlevels
  'notuse',...  % 5 multitime contour
  'notuse','notuse','notuse','notuse','notuse',...
  'surface',... % 11 surface plot
  'notuse','notuse','notuse','notuse',...
  '.mp4',...    % 16 save as .mp4 format
  'notuse',...  % 17 save as ASCII format
  'notuse'...
  };


pflag=zeros(size(pflagmap));
for i=1:length(plotflag), pflag = bitor(pflag,strcmp(pflagmap,plotflag{i})); end
% reorder bits to use bitget
pflag = sortrows([length(pflag):-1:1; pflag]',1);
pflag = bin2dec(num2str(pflag(:,2)'));
% pflag = bitset(pflag,11);

% defaults
load global_vars ...
	nrows ncols cellord layers aquifers
d_ihm = 'F:\IHM';
GEOcoastline = shaperead(fullfile(d_ihm,'shapefiles\INTBcoastline.shp'));
% %GEOroad      = shaperead(fullfile(d_ihm,'shapefiles\INTBroad.shp'));
GEOwellfield = shaperead(fullfile(d_ihm,'shapefiles\INTBwellfield.shp'));
% GEOcounty    = shaperead(fullfile(d_ihm,'shapefiles\INTBcounty.shp'));
% GEOextend    = shaperead(fullfile(d_ihm,'shapefiles\INTB_extend.shp'));

X = unique(cellord(:,2));
Y = sort(unique(cellord(:,3)),'descend');
[XX,YY] = meshgrid(X,Y);
% contour smoothing parameters using interp2
gridsz = 500.0; % in kilometer or same unit as X, Y
IX = X(1):gridsz:X(end);
IY = (Y(1):-gridsz:Y(end))';
[XI YI] = meshgrid(IX,IY);
% contour smoothing parameter for conv2
convfilt = [.05 .1 .05; .1 .4 .1; .05 .1 .05];
% Color scale by layer
cscale = {[-20 240] [-20 240]};
% minmax = cscale;

%% Read heads by layer
hmat = ReadHead(headfile,0,layers,skip_tstep+tsteps);

% [~,a_cont] = create1x2Axes('Contour plots for INTB Simulation');  
demcmap(cscale{1},27);

% for i = 1:5
    sim_date = sim_tstart - data_interval;
    for t = 1:(tsteps(1)-1)
        sim_date = sim_date + data_interval;
        sim_date = sim_date - day(sim_date) + 1;
    end
    for t = 1:length(tsteps)
        sim_date = sim_date + data_interval;
        sim_date = sim_date - day(sim_date) + 1;
        plot_one;
    end
    mapshow(GEOwellfield,'EdgeColor','y','FaceColor','none','LineWidth',2);
    mapshow(GEOcoastline,'Color',[.5 .75 1],'LineWidth',0.25);
    if bitget(pflag,16)
        if bitget(pflag,11)
            print('-dtiff', '-r100', '-loose', ['.\images\' sprintf('c%04d',t)]);
            !ffmpeg -r 3 -i c%04d.tif -sameq -r 24 ..\surface.mp4
        else
            print('-dtiff', '-r100', '-loose', ['.\images\' sprintf('s%04d',t)]);
            !ffmpeg -r 3 -i s%04d.tif -sameq -r 24 ..\surface.mp4
        end
    end
    pause(5);
% end

function plot_one
%% Plot contour
%     [~,a_cont] = create1x2Axes(...
%       sprintf('Contour plots for INTB Simulation time step %d',tsteps(t)));  
%     for l = 1:length(layers)
    for l = 2:2
      % surficial aquifer may have different footprints of active cell.
      % This may cause problem in some applications
      Z = hmat(:,t,l);
      acells = Z~=-9999;
      
%       subplot(a_cont(l,1));
      Z(~acells) = 0;
%       minmax{l}(1) = min(min(Z),minmax{l}(1));
%       minmax{l}(2) = max(max(Z),minmax{l}(2));
      Z = reshape(Z,ncols,nrows)';
      if bitget(pflag,11)
        h = surf(XI,YI,interp2(XX,YY,Z,XI,YI,'cubic'),...
            'FaceColor','interp','EdgeColor','none',...
            'FaceLighting','phong');
        daspect([400 400 1]);
        axis tight;
        view(-15,60);
        camlight left;
      else
        [~,h] = contourf(X,Y,conv2(Z,convfilt,'same'));
%         [~,h] = contour(IX,IY,interp2(X,Y,Z,XI,YI,'cubic'));
        set(h,'LineWidth',0.25);
        mapshow(GEOwellfield,'EdgeColor','y','FaceColor','none','LineWidth',2);
        mapshow(GEOcoastline,'Color',[.5 .75 1],'LineWidth',0.25);
        daspect([1 1 1]);
        caxis(cscale{l});
        colorbar('EastOutside','FontSize',7);
%         % scatter plot
%         ZV = Z(acells);
%         XV = cellord(acells,2)/1000;
%         YV = cellord(acells,3)/1000;
%         scatter(XV,YV,4,ZV,'filled');
      end
      set(gca,'FontSize',7);

%       title(['\bf\fontsize{10}' aquifers{l}]);
      title(['\bf\fontsize{10}' datestr(sim_date)],'FontSize',10);
      xlabel('UTM Easting, km');
      ylabel('UTM Northing, km');
    end
%     d_graph = fullfile('.\contour',sprintf('contour_%3d',t));
%     exportFig2PDF(d_graph,sprintf('Cont_%s_day%03d',,tsteps(t)));
    drawnow;
    if bitget(pflag,16)
        if bitget(pflag,11)
            print('-dtiff', '-r100', '-loose', ['.\images\' sprintf('c%04d',t)]);
        else
            print('-dtiff', '-r100', '-loose', ['.\images\' sprintf('s%04d',t)]);
        end
    end
    pause(0.1);
end


function [h,a] = create1x2Axes(ptitle)
% Template for subplots 1x2 landscape
h = figwindow(ptitle,1);

% Calculation of positions based on 2x2 subplots
r = 1; c = 2;
vgap = 0.075;
hgap = 0.075;
vsize = (0.92-r*vgap)/r;
hsize = (1-c*hgap)/c;
vpos(1) = 0.92-vsize;
hpos(1) = 0.75*hgap;
hpos(2) = hpos(1)+(hgap+hsize);
a(1,1) = subplot('Position',[hpos(1),vpos(1),hsize,vsize]);
a(2,1) = subplot('Position',[hpos(2),vpos(1),hsize,vsize]);
set(a(1,1),'FontSize',7);
set(a(2,1),'FontSize',7);
% dummy axis for figure title
axes('Position',[0,0,1,1],'Visible','off');
text(0.5,0.975,['\bf' ptitle],'HorizontalAlignment','center','FontSize',9);
end


end
