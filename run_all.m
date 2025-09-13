%RUN_ALL Run optimization and verification pipeline.

clear; clc;
addpath(genpath(pwd));

outDir = fullfile(pwd,'artifacts',datestr(now,'yyyymmdd_HHMMSS'));
if ~exist(outDir,'dir'), mkdir(outDir); end

mdl = 'mdl_lut';
if ~bdIsLoaded(mdl)
    load_system(mdl);
end
open_system(mdl);

if ~evalin('base','exist(''STOP_T'',''var'')), assignin('base','STOP_T',10); end
if ~evalin('base','exist(''BP'',''var'')), assignin('base','BP',linspace(-1,1,11)); end
if ~evalin('base','exist(''TBL'',''var'')), assignin('base','TBL',zeros(size(evalin('base','BP')))); end

fprintf('=== Run - Optimize - Verify ===\n');
tAll = tic;
run_pso;
verify_lut;
save_all_figs(outDir);
fprintf('Artifacts dir: %s\n',outDir);
fprintf('Total time: %.3f s\n',toc(tAll));

function save_all_figs(outdir)
figs = findall(0,'Type','figure');
for k=1:numel(figs)
    base = fullfile(outdir,sprintf('fig_%02d',k));
    saveas(figs(k),[base '.png']);
    try savefig(figs(k),[base '.fig']); end
end
end
