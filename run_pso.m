function run_pso()
%RUN_PSO Optimize the LUT values using a basic PSO search.

mdl = 'mdl_lut';
if ~bdIsLoaded(mdl)
    load_system(mdl);
end

if ~evalin('base','exist(''STOP_T'',''var''))
    assignin('base','STOP_T',10);
end
if ~evalin('base','exist(''BP'',''var''))
    assignin('base','BP',linspace(-1,1,11));
end
BP = evalin('base','BP');
if ~evalin('base','exist(''TBL'',''var'')) || ~isequal(size(evalin('base','TBL')),size(BP))
    assignin('base','TBL',zeros(size(BP)));
end

try set_param([mdl '/J_to_ws'],'VariableName','J','SaveFormat','Array'); end
try set_param(mdl,'FastRestart','on'); end
try set_param(mdl,'ReturnWorkspaceOutputs','on'); end

opt.mdl     = mdl;
opt.tblSize = size(evalin('base','TBL'));
opt.bounds  = [-2 2];

pso.nSwarm  = 50;
pso.maxIter = 80;
pso.w  = 0.7;
pso.c1 = 1.6;
pso.c2 = 1.6;

x0 = evalin('base','TBL(:)');
[bestX,bestJ,histJ] = pso_optimize_lut(x0,opt,pso);
assignin('base','TBL',reshape(bestX,opt.tblSize));
assignin('base','histJ',histJ);

simOut = sim(mdl);
if isa(simOut,'Simulink.SimulationOutput') && any(strcmp(who(simOut),'J'))
    Jv = simOut.get('J');
else
    Jv = evalin('base','J');
end
if isa(Jv,'timeseries')
    J_final = Jv.Data(end);
elseif isnumeric(Jv)
    J_final = Jv(end);
else
    J_final = NaN;
end

fprintf('Best J: %.6g\n',bestJ);
fprintf('Final J: %.6g\n',J_final);
try save_system(mdl); end
end
