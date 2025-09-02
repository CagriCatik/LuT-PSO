% run_no_pso.m
% Run the model without PSO, simulate once, and verify statically.

clear; clc;

% ----- Base variables -----
STOP_T = 10;
BP     = linspace(-1,1,11);
TBL    = zeros(size(BP));

assignin('base','STOP_T',STOP_T);
assignin('base','BP',BP);
assignin('base','TBL',TBL);

% ----- Ensure model exists and is loaded -----
mdl = 'mdl_lut';
if ~bdIsLoaded(mdl)
    if exist([mdl '.slx'],'file') == 2
        load_system(mdl);
    elseif exist('build_mdl_lut','file') == 2
        build_mdl_lut;
    else
        error('Model mdl_lut not found. Run build_mdl_lut first.');
    end
end

% ----- Model I/O settings -----
try, set_param([mdl '/J_to_ws'],'VariableName','J','SaveFormat','Array'); catch, end
try, set_param(mdl,'ReturnWorkspaceOutputs','on'); catch, end
try, set_param(mdl,'FastRestart','on'); catch, end

% ----- Simulate once -----
simOut = sim(mdl);

% Extract J
J_final = NaN;
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
fprintf('Simulation J: %.6g\n', J_final);

% ----- Verification: LUT vs reference -----
% Read the reference expression from the Fcn block, fallback to tanh(2*u)
refExpr = 'tanh(2*u)';
try, refExpr = get_param([mdl '/refFcn'],'Expr'); catch, end
refFcn  = @(u) eval_ref_expr(refExpr, u);
vec_ref = @(x) arrayfun(refFcn, x);

% 1) Breakpoint comparison
Tref = vec_ref(BP);
figure('Name','Breakpoints','NumberTitle','off');
plot(BP, Tref, '-o', 'LineWidth', 1.5); hold on;
plot(BP, TBL,  '-x', 'LineWidth', 1.5);
legend('target at BP','TBL','Location','best');
grid on; xlabel('u'); ylabel('y');
title('Breakpoint vs. Table Values');

% 2) Dense grid comparison (linear + clip extrap)
uu     = linspace(min(BP), max(BP), 1000);
y_ref  = vec_ref(uu);
uu_clip = min(max(uu, BP(1)), BP(end));
y_lut  = interp1(BP, TBL, uu_clip, 'linear');
err    = y_ref - y_lut;
mse_grid = mean(err.^2);
fprintf('Grid MSE (static): %.6g\n', mse_grid);

figure('Name','Static Sweep','NumberTitle','off');
plot(uu, y_ref, '-',  'LineWidth', 1.5); hold on;
plot(uu, y_lut, '--', 'LineWidth', 1.5);
legend('y_ref(u)','y_lut(u)','Location','best');
grid on; xlabel('u'); ylabel('y');
title('Static Sweep Comparison');

% ----- Local function -----
function y = eval_ref_expr(expr, u)
try
    y = eval(expr); % expression uses variable "u"
catch
    if strcmp(strtrim(expr),'tanh(2*u)')
        y = tanh(2*u);
    else
        error('Could not evaluate reference expression: %s', expr);
    end
end
end
