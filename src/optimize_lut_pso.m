function [TBL_best, bestJ, J_final, histJ] = optimize_lut_pso(cfg)
% Run PSO for LUT optimization and simulate final result.
% cfg fields:
%   mdl, bounds[1x2], lambda_mon, lambda_smooth, pso struct

% Normalize cfg
mdl           = char(cfg.mdl);
bounds        = cfg.bounds(:).';
lambda_mon    = cfg.lambda_mon;
lambda_smooth = cfg.lambda_smooth;
pso           = cfg.pso;

% Initial vector from base
x0 = evalin('base','TBL(:)');
tblSize = size(evalin('base','TBL'));

% Cost options for eval
opt.mdl           = mdl;
opt.tblSize       = tblSize;
opt.bounds        = bounds;
opt.lambda_mon    = lambda_mon;
opt.lambda_smooth = lambda_smooth;

% Run generic PSO
costFcn = @(x) eval_lut_cost(x, opt);
[bestX, bestJ, histJ] = pso_optimize(costFcn, x0, pso, bounds);

% Apply best table to base and simulate
TBL_best = reshape(bestX, tblSize);
assignin('base','TBL', TBL_best);

try
    simOut = sim(mdl);
catch
    simOut = [];
end
J_final = sim_read_J(simOut);

fprintf('\nBest J (PSO): %.6g\n', bestJ);
fprintf('Final J (sim with best TBL): %.6g\n', J_final);
end
