function J = eval_lut_cost(x, opt)
% x: column vector of LUT values
% opt.mdl, opt.tblSize, opt.bounds, opt.lambda_mon, opt.lambda_smooth

% 1) set LUT in base workspace
TBL = reshape(x, opt.tblSize);
assignin('base','TBL', TBL);

% 2) ensure outputs are returned in SimulationOutput
try
    set_param(opt.mdl, 'ReturnWorkspaceOutputs', 'on');
catch
    % ok if this parameter is not present
end

% 3) run simulation
simOut = sim(opt.mdl);

% 4) fetch J
J_ws = [];
if isa(simOut, 'Simulink.SimulationOutput')
    vars = who(simOut);
    if any(strcmp(vars, 'J'))
        J_ws = simOut.get('J');
    end
end
if isempty(J_ws)
    if evalin('base','exist(''J'',''var'')')
        J_ws = evalin('base','J');
    else
        error('eval_lut_cost:NoJ', ...
            'J not found. Set the To Workspace VariableName to ''J'' (SaveFormat=Array or Structure With Time).');
    end
end

% 5) normalize J to a scalar
if isnumeric(J_ws)
    Jsim = J_ws(end);
elseif isa(J_ws,'timeseries')
    Jsim = J_ws.Data(end);
elseif isstruct(J_ws) && isfield(J_ws,'signals') && isfield(J_ws.signals,'values')
    Jsim = J_ws.signals.values(end);
elseif isa(J_ws,'Simulink.SimulationData.Dataset')
    el = J_ws.get(1);
    if isa(el,'timeseries'), Jsim = el.Data(end); else, error('eval_lut_cost: UnsupportedFormat'); end
else
    error('eval_lut_cost: UnsupportedFormat');
end

% 6) penalties
pen = 0;
if isfield(opt,'bounds') && ~isempty(opt.bounds)
    lb = opt.bounds(1); ub = opt.bounds(2);
    over  = max(0, TBL - ub);
    under = max(0, lb - TBL);
    pen = pen + 1e6 * (sum(over(:).^2) + sum(under(:).^2));
end
if isfield(opt,'lambda_mon') && opt.lambda_mon > 0
    d1 = diff(TBL(:));
    pen = pen + opt.lambda_mon * sum(max(0, -d1));
end
if isfield(opt,'lambda_smooth') && opt.lambda_smooth > 0
    d2 = diff(TBL(:),2);
    pen = pen + opt.lambda_smooth * sum(d2.^2);
end

J = Jsim + pen;
end
