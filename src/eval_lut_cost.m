function J = eval_lut_cost(x, opt)
% Compute cost for a candidate LUT vector.
% x: column vector
% opt: struct with fields .mdl .tblSize .bounds .lambda_mon .lambda_smooth

assert(isfield(opt,'mdl') && ~isempty(opt.mdl), 'opt.mdl missing');
assert(isfield(opt,'tblSize') && ~isempty(opt.tblSize), 'opt.tblSize missing');

mdl = char(opt.mdl);
tblSize = opt.tblSize;

% Bounds
if isfield(opt,'bounds') && ~isempty(opt.bounds)
    lb = opt.bounds(1);
    ub = opt.bounds(2);
else
    lb = -inf; ub = inf;
end
lambda_mon    = getfield_with_default(opt,'lambda_mon',0);
lambda_smooth = getfield_with_default(opt,'lambda_smooth',0);

% Reshape and clamp
x = x(:);
if numel(x) ~= prod(tblSize)
    error('eval_lut_cost:sizeMismatch','x has %d elems, expected %d.', numel(x), prod(tblSize));
end
TBL = reshape(x, tblSize);
if isfinite(lb) || isfinite(ub)
    TBL = min(max(TBL, lb), ub);
end
assignin('base','TBL', TBL);

% Simulate
try
    simOut = sim(mdl);
catch
    simOut = [];
end
Jcore = sim_read_J(simOut);
if ~isfinite(Jcore)
    % If model did not produce J, penalize heavily
    Jcore = 1e12;
end

% Regularization
pen_mon = 0;
pen_smo = 0;

BP = [];
try
    if evalin('base','exist(''BP'',''var'')'), BP = evalin('base','BP'); end
catch
end

v = TBL(:);
if lambda_mon > 0
    d = diff(v);
    pen_mon = lambda_mon * sum(max(0, -d).^2);
end
if lambda_smooth > 0
    if numel(v) >= 3
        d2 = diff(v,2);
        pen_smo = lambda_smooth * sum(d2.^2);
    end
end

J = Jcore + pen_mon + pen_smo;
end

function v = getfield_with_default(s, field, def)
if isfield(s, field) && ~isempty(s.(field))
    v = s.(field);
else
    v = def;
end
end
