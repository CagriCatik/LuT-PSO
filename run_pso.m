% Step 3 driver: optimize the LUT with PSO.

% prerequisites:
%   - build_mdl_lut executed once
%   - eval_lut_cost.m on path
%   - model mdl_lut uses base vars BP, TBL, STOP_T and writes J

% options for cost
opt.mdl = 'mdl_lut';
opt.tblSize = size(evalin('base','TBL'));
opt.bounds = [-2, 2];     % adjust if needed
opt.lambda_mon = 0;       % set >0 to encourage monotonic TBL
opt.lambda_smooth = 1e-2; % light smoothing

% PSO params
pso.nSwarm  = 50;
pso.maxIter = 25;
pso.w  = 0.7;
pso.c1 = 1.6;
pso.c2 = 1.6;
pso.display = 'iter';

% initial vector
x0 = evalin('base','TBL(:)');

% run PSO
[bestX, bestJ, histJ] = pso_optimize_lut(x0, opt, pso);

% apply best table back to base workspace and model
TBL_best = reshape(bestX, opt.tblSize);
assignin('base','TBL', TBL_best);

% final check
simOut = sim(opt.mdl);
if isa(simOut,'Simulink.SimulationOutput') && any(strcmp(who(simOut),'J'))
    J_final = simOut.get('J');
    if isnumeric(J_final), J_final = J_final(end);
    elseif isa(J_final,'timeseries'), J_final = J_final.Data(end);
    elseif isstruct(J_final) && isfield(J_final,'signals') && isfield(J_final.signals,'values')
        J_final = J_final.signals.values(end);
    end
else
    Jv = evalin('base','J');
    if isnumeric(Jv), J_final = Jv(end);
    elseif isa(Jv,'timeseries'), J_final = Jv.Data(end);
    else, J_final = NaN;
    end
end

fprintf('\nBest J (from PSO): %.6g\n', bestJ);
fprintf('Final J (after applying best TBL): %.6g\n', J_final);

% optional: save model state
save_system(opt.mdl);
