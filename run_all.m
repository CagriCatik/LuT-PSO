% Entry: configure, optimize, verify, and save artifacts.

clear; clc; rng(1);
addpath(genpath(fileparts(mfilename('fullpath'))));

% ===== CONFIG =====
cfg.mdl            = 'mdl_lut';      % Simulink model name
cfg.bounds         = [-2 2];         % LUT value bounds
cfg.lambda_mon     = 0;              % monotonicity penalty weight
cfg.lambda_smooth  = 1e-2;           % smoothness penalty weight
cfg.target_fun     = @(u) tanh(2*u); % analytic reference for verification
cfg.pso.nSwarm     = 50;             % swarm size
cfg.pso.maxIter    = 120;            % max iterations
cfg.pso.w          = 0.7;            % inertia
cfg.pso.c1         = 1.6;            % cognitive weight
cfg.pso.c2         = 1.6;            % social weight
cfg.pso.display    = 'iter';         % 'iter' or 'none'
cfg.pso.tolFun     = 1e-4;           % early stop threshold on |delta bestJ|
cfg.pso.stallIter  = 10;             % early stop patience
open_model_window  = false;          % set false for headless runs
% ===================

% Artifacts out dir
timestamp = char(datetime("now","Format","yyyyMMdd_HHmmss"));
ARTIFACTS_ROOT = fullfile(pwd,'artifacts');
OUT_DIR = fullfile(ARTIFACTS_ROOT, timestamp);
if ~exist(ARTIFACTS_ROOT,'dir'), mkdir(ARTIFACTS_ROOT); end
if ~exist(OUT_DIR,'dir'), mkdir(OUT_DIR); end

% Load model (search path and repo)
find_and_load_model(cfg.mdl);
if open_model_window
    try open_system(cfg.mdl); catch, end
end

% Prepare workspace and model settings
[BP] = prepare_model_and_workspace(cfg.mdl);

pause(1.0);  % small settle

% Optimize with PSO
figs_before = findall(0,'Type','figure');
[TBL_best, bestJ, J_final, histJ] = optimize_lut_pso(cfg);
save_new_figures(figs_before, OUT_DIR, 'pso_stage');

% Verify and plot
BP = evalin('base','BP');           % in case user replaced it
TBL = evalin('base','TBL');
mse_grid = verify_lut_results(BP, TBL, cfg.target_fun, histJ);
figs_before = findall(0,'Type','figure');
save_new_figures(figs_before, OUT_DIR, 'verify_stage'); % none if unchanged

% Save any remaining open figures (safety)
figs = findall(0,'Type','figure');
for i = 1:numel(figs)
    nm = get(figs(i),'Name'); if isempty(nm), nm = sprintf('fig_%02d',i); end
    base = fullfile(OUT_DIR, sanitize_filename(nm));
    save_plot(figs(i), base);
end

% Summary
fprintf('\n=== Summary ===\n');
fprintf('Artifacts dir       : %s\n', OUT_DIR);
fprintf('Best J (PSO)        : %.6g\n', bestJ);
fprintf('Final J (simulate)  : %.6g\n', J_final);
fprintf('Grid MSE (static)   : %.6g\n', mse_grid);
