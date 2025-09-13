function J = eval_lut_cost(x,opt)
%EVAL_LUT_COST Simulate model with table values x and return scalar cost.

TBL = reshape(x,opt.tblSize);
assignin('base','TBL',TBL);

simOut = sim(opt.mdl);
if isa(simOut,'Simulink.SimulationOutput')
    Jv = simOut.get('J');
else
    Jv = evalin('base','J');
end
if isa(Jv,'timeseries')
    Jsim = Jv.Data(end);
else
    Jsim = Jv(end);
end

pen = 0;
if isfield(opt,'bounds')
    lb = opt.bounds(1); ub = opt.bounds(2);
    pen = pen + 1e6*sum(max(0,lb-TBL(:)).^2 + max(0,TBL(:)-ub).^2);
end
if isfield(opt,'lambda_mon') && opt.lambda_mon>0
    pen = pen + opt.lambda_mon*sum(max(0,-diff(TBL(:))));
end
if isfield(opt,'lambda_smooth') && opt.lambda_smooth>0
    pen = pen + opt.lambda_smooth*sum(diff(TBL(:),2).^2);
end

J = Jsim + pen;
end
