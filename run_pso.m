function run_pso()
% Optimize the LUT with PSO (self-initializing).

mdl = 'mdl_lut';

% ---------- Ensure model exists and is loaded ----------
if ~bdIsLoaded(mdl)
    if exist([mdl '.slx'],'file') == 2
        load_system(mdl);
    elseif exist('build_mdl_lut','file') == 2
        build_mdl_lut;
    else
        error('run_pso:ModelMissing', ...
              'Model mdl_lut not found and build_mdl_lut.m is missing.');
    end
end

% ---------- Ensure required workspace variables ----------
if ~evalin('base','exist(''STOP_T'',''var'')')
    assignin('base','STOP_T', 10);
end
if ~evalin('base','exist(''BP'',''var'')')
    assignin('base','BP', linspace(-1,1,11));
end
BP = evalin('base','BP');

if ~evalin('base','exist(''TBL'',''var'')')
    assignin('base','TBL', zeros(size(BP)));
else
    TBLcur = evalin('base','TBL');
    if ~isequal(size(TBLcur), size(BP))
        assignin('base','TBL', zeros(size(BP)));
    end
end

% ---------- Model sink settings and fast loop ----------
try set_param([mdl '/J_to_ws'], 'VariableName','J', 'SaveFormat','Array'); catch, end
try set_param(mdl,'FastRestart','on'); catch, end
try set_param(mdl,'ReturnWorkspaceOutputs','on'); catch, end

% ---------- Cost options ----------
opt.mdl = mdl;
opt.tblSize = size(evalin('base','TBL'));
opt.bounds = [-2, 2];
opt.lambda_mon = 0;
opt.lambda_smooth = 1e-2;

% ---------- PSO params ----------
pso.nSwarm  = 25;
pso.maxIter = 80;
pso.w  = 0.7;
pso.c1 = 1.6;
pso.c2 = 1.6;
pso.display = 'iter';

% ---------- Initial vector ----------
x0 = evalin('base','TBL(:)');

% ---------- Run PSO ----------
[bestX, bestJ, histJ] = pso_optimize_lut(x0, opt, pso);
assignin('base','histJ', histJ);

% ---------- Apply best table ----------
TBL_best = reshape(bestX, opt.tblSize);
assignin('base','TBL', TBL_best);

% ---------- Final check ----------
simOut = sim(opt.mdl);
J_final = NaN;
if isa(simOut,'Simulink.SimulationOutput') && any(strcmp(who(simOut),'J'))
    Jv = simOut.get('J');
else
    if evalin('base','exist(''J'',''var'')')
        Jv = evalin('base','J');
    else
        Jv = [];
    end
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

fprintf('\nBest J (from PSO): %.6g\n', bestJ);
fprintf('Final J (after applying best TBL): %.6g\n', J_final);

try save_system(opt.mdl); catch, end
end
