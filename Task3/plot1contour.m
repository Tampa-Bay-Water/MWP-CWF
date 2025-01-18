function [h,cb]=plot1contour(g_temp,cscale,pflag)
if nargin<3, pflag=false; end

% grid id from shapefile may not in sorting order
gridid = [g_temp.GRIDID]';
[~,IZ] = sort(gridid);
g_temp = g_temp(IZ);
X = unique([g_temp.X]');
Y = sort(unique([g_temp.Y]'),'descend');
Z = [g_temp.DDN]';
% Z(Z=-9999) = 0;
nrows = floor(g_temp(end).GRIDID/1000);
ncols = mod(g_temp(end).GRIDID,1000);
Z = reshape(Z,ncols,nrows)';

if pflag
    [XX,YY] = meshgrid(X,Y);
    % contour smoothing parameters using interp2
    gridsz = 500.0; % in kilometer or same unit as X, Y
    IX = X(1):gridsz:X(end);
    IY = (Y(1):-gridsz:Y(end))';
    [XI,YI] = meshgrid(IX,IY);
    h = surf(XI,YI,interp2(XX,YY,Z,XI,YI,'cubic'),...
        'FaceColor','interp','EdgeColor','none',...
        'FaceLighting','phong');
    daspect([400 400 1]);
    axis tight;
    view(-15,60);
    camlight left;
else
    % contour smoothing parameter for conv2
    convfilt = [.05 .1 .05; .1 .4 .1; .05 .1 .05];
    [~,h] = contourf(X,Y,conv2(Z,convfilt,'same'));
    % [~,h] = contour(IX,IY,interp2(X,Y,Z,XI,YI,'cubic'));
    set(h,'LineWidth',0.25);
    daspect([1 1 1]);
    clim(cscale);
    cb = colorbar('SouthOutside','FontSize',7);
end