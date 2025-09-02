% run_optimize_and_verify.m

clear; clc;
rng(1);
addpath(genpath(pwd));

fprintf('=== Run - Optimize - Verify ===');

%%  Output directory 
timestamp = char(datetime("now", "Format", "yyyyMMdd_HHmmss"));

OUT_DIR = fullfile(pwd, 'artifacts', timestamp);

if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

%% Locate, load, and open the model
mdl = 'mdl_lut';

if ~bdIsLoaded(mdl)

    % Try on MATLAB path
    f = which([mdl '.slx']);
    if isempty(f), f = which([mdl '.mdl']); end

    % If not on path, search under current repo tree
    if isempty(f)
        d = dir(fullfile(pwd, '**', [mdl '.slx']));
        if isempty(d)
            d = dir(fullfile(pwd, '**', [mdl '.mdl']));
        end
        if ~isempty(d)
            f = fullfile(d(1).folder, d(1).name);
        end
    end

    if isempty(f)
        error('Model %s not found on path or under %s.', mdl, pwd);
    end

    load_system(f);
end

%% Open model window (optional)
try
    open_system(mdl);
catch ME
    warning('Could not open model window: %s', error.message);
end



%%  Ensure required workspace vars 
if ~evalin('base','exist(''STOP_T'',''var'')')
    assignin('base','STOP_T', 10);
end
if ~evalin('base','exist(''BP'',''var'')')
    assignin('base','BP', linspace(-1,1,11));
end
BP = evalin('base','BP');
if ~evalin('base','exist(''TBL'',''var'')')
    assignin('base','TBL', zeros(size(BP)));
end

%%  Preferred model settings 
try set_param(mdl,'FastRestart','on'); catch, end
try set_param(mdl,'ReturnWorkspaceOutputs','on'); catch, end
try set_param([mdl '/J_to_ws'],'VariableName','J','SaveFormat','Array'); catch, end

fprintf('\n=== Wait for 2 seconds to open and load the model ===\n');

pause(2)

t_all = tic;

%%  PSO 
t_pso = tic;
if exist('run_pso','file') ~= 2
    error('run_pso.m not found on path.');
end

%% Capture figures opened before PSO (in case run_pso plots)
figs_before_pso = findall(0,'Type','figure');
run_pso;

%% Save any figures created by run_pso
save_new_figures(figs_before_pso, OUT_DIR, 'pso_stage');
t_pso = toc(t_pso);

%%  Final J from sim (for summary) 
J_final = NaN;
try
    simOut = sim(mdl);
    if isa(simOut,'Simulink.SimulationOutput') && any(strcmp(who(simOut),'J'))
        Jv = simOut.get('J');
    elseif evalin('base','exist(''J'',''var'')')
        Jv = evalin('base','J');
    else
        Jv = [];
    end
    if isnumeric(Jv)
        J_final = Jv(end);
    elseif isa(Jv,'timeseries')
        J_final = Jv.Data(end);
    elseif isstruct(Jv) && isfield(Jv,'signals') && isfield(Jv.signals,'values')
        J_final = Jv.signals.values(end);
    elseif isa(Jv,'Simulink.SimulationData.Dataset')
        el = Jv.get(1); J_final = el.Data(end);
    end
catch
    % ignore
end

%%  Verification 
t_ver = tic;
verify_called = false;
verify_names = {'run_verify_and_convergence','verify_and_convergence','run_verification'};
for k = 1:numel(verify_names)
    if exist(verify_names{k},'file') == 2
        figs_before_verify = findall(0,'Type','figure');
        feval(verify_names{k});
        save_new_figures(figs_before_verify, OUT_DIR, 'verify_stage');
        verify_called = true;
        break;
    end
end

if ~verify_called
    % Built-in verification (fallback)
    BP  = evalin('base','BP');
    TBL = evalin('base','TBL');

    % Reference expression from model, fallback to tanh(2*u)
    refExpr = 'tanh(2*u)';
    try refExpr = get_param([mdl '/refFcn'], 'Expr'); catch, end
    refFcn = @(u) eval_ref_expr(refExpr, u);
    vec_ref = @(x) arrayfun(refFcn, x);

    % Breakpoint comparison
    Tref = vec_ref(BP);
    f1 = figure('Name','Breakpoints','NumberTitle','off');
    plot(BP, Tref, '-o', 'LineWidth', 1.5); hold on;
    plot(BP, TBL,  '-x', 'LineWidth', 1.5);
    legend('target at BP','optimized TBL','Location','best');
    grid on; xlabel('u'); ylabel('y'); title('Breakpoint vs. Table Values');
    save_plot(f1, fullfile(OUT_DIR,'breakpoints'));

    % Dense grid comparison (linear + clip)
    uu = linspace(min(BP), max(BP), 1000);
    y_ref = vec_ref(uu);
    uu_clip = min(max(uu, BP(1)), BP(end));
    y_lut = interp1(BP, TBL, uu_clip, 'linear');
    err = y_ref - y_lut;
    mse_grid = mean(err.^2);
    fprintf('Grid MSE (static): %.6g\n', mse_grid);

    f2 = figure('Name','Static Sweep','NumberTitle','off');
    plot(uu, y_ref, '-', 'LineWidth', 1.5); hold on;
    plot(uu, y_lut, '--', 'LineWidth', 1.5);
    legend('y_ref(u)','y_lut(u)','Location','best');
    grid on; xlabel('u'); ylabel('y'); title('Static Sweep Comparison');
    save_plot(f2, fullfile(OUT_DIR,'static_sweep'));
end
t_ver = toc(t_ver);

t_all = toc(t_all);

%%  Summary 
bestJ = NaN;
if evalin('base','exist(''histJ'',''var'')')
    hj = evalin('base','histJ');
    if ~isempty(hj), bestJ = min(hj(:)); end
end

fprintf('\n=== Summary ===\n');
fprintf('Artifacts dir       : %s\n', OUT_DIR);
fprintf('PSO time            : %.3f s\n', t_pso);
fprintf('Verification time   : %.3f s\n', t_ver);
fprintf('Total time          : %.3f s\n', t_all);

if ~isnan(bestJ), fprintf('Best J (PSO)        : %.6g\n', bestJ); end
if ~isnan(J_final), fprintf('Final J (simulate)  : %.6g\n', J_final); end

%% Local functions
function y = eval_ref_expr(expr, u)
try
    y = eval(expr); % expression uses variable u
catch
    if strcmp(strtrim(expr),'tanh(2*u)')
        y = tanh(2*u);
    else
        error('Could not evaluate reference expression: %s', expr);
    end
end
end

%% Save as .png and .fig; try exportgraphics first, fallback to print/saveas.
function save_plot(figHandle, basePath)
pngPath = [basePath '.png'];
figPath = [basePath '.fig'];
try
    exportgraphics(figHandle, pngPath, 'Resolution', 200);
catch
    try
        set(figHandle,'PaperPositionMode','auto');
        print(figHandle, pngPath, '-dpng','-r200');
    catch
        % last resort
    end
end
try
    savefig(figHandle, figPath);
catch
    % ignore
end
end

%% Save figures that were created after a given checkpoint.
function save_new_figures(figs_before, out_dir, prefix)
figs_after = findall(0,'Type','figure');
new_figs = setdiff(figs_after, figs_before);
if isempty(new_figs), return; end
% Stable order by creation number (ascending)
[~, idx] = sort(arrayfun(@(h) h.Number, new_figs));
new_figs = new_figs(idx);
for i = 1:numel(new_figs)
    name = get(new_figs(i), 'Name');
    if isempty(name)
        name = sprintf('%s_%02d', prefix, i);
    else
        name = sprintf('%s_%s_%02d', prefix, sanitize_filename(name), i);
    end
    base = fullfile(out_dir, name);
    save_plot(new_figs(i), base);
end
end

%% Replace non-filename characters with underscores.
function s = sanitize_filename(nameStr)
s = regexprep(nameStr,'[^a-zA-Z0-9_-]','_');
s = regexprep(s,'_+','_');
end
