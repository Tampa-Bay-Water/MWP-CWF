function fig2pdf
d_cur = fileparts(mfilename("fullpath"));
d_fig = fullfile(d_cur,'task3_3_plots');
d_pdf = fullfile(d_cur,'task3_3_pdf');

if exist([d_fig,'.pdf'],"file"), delete([d_fig,'.pdf']); end
if ~exist(d_pdf,"dir"), mkdir(d_pdf); end
fig_fnames = dir(fullfile(d_fig,'*.fig'));
[~,i_sort] = sort([fig_fnames.datenum]);
fig_fnames = {fig_fnames(i_sort).name};
nfig = length(fig_fnames);
for i=1:nfig
    fig = openfig(fullfile(d_fig,fig_fnames{i}));
    fig.WindowStyle = 'normal';
    drawnow;

    res = 300;
    if strcmpi(fig.PaperOrientation,'landscape')
        fig.Resize = 'off';
        fig.PaperPosition = [0.3000 0.3000 10.4000 7.9000];
        % fig.PaperSize = [12.3333 9.4167];
        fig.Position = [5 420 1196 924];
        fig.OuterPosition = [5 420 1196 924];
        fig.InnerPosition = [5 420 1196 924];
    % else
    %     fig.Resize = 'off';
    %     fig.PaperPosition = [0.3000 0.3000 7.9000 10.4000];
    %     % fig.PaperSize = [ 9.4167 12.3333];
    %     fig.Position = [5 420 714 946];
    %     fig.OuterPosition = [5 420 714 946];
    %     fig.InnerPosition = [5 420 714 946];
    end
    % exportgraphics(fig,fullfile(d_pdf,[fig_fnames{i}(1:end-4),'.pdf']) ...
    %     ,'Resolution',res ...
    %     ,'Padding',20 ...
    %     );
    exportgraphics(fig,[d_fig '.pdf']...
        ,'Resolution',res ...
        ,'Padding',20 ...
        ,'Append',true ...
        );
    close(fig);
end


% merge1pdf(fullfile(d_figs,'*.pdf'),'temp',false,true);
%{
system(['/opt/homebrew/bin/pwsh -Command "Merge-PDF ',...
    '(Get-ChildItem ',d_figs, '/*.pdf |',...
    'Sort-Object -Property LastWriteTime |%{$_.FullName}) ','temp','"']);
%}