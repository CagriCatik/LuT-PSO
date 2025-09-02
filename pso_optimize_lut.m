function [bestX, bestJ, histJ] = pso_optimize_lut(x0, opt, pso)

% PSO for LUT vectors.
% x0     : column vector initial guess (TBL(:))
% opt    : struct for eval_lut_cost (mdl, tblSize, bounds, lambda_mon, lambda_smooth)
% pso    : optional struct fields: nSwarm, maxIter, w, c1, c2, display

% ----- defaults -----
if nargin < 3, pso = struct; end
if ~isfield(pso,'nSwarm'),  pso.nSwarm  = 25; end
if ~isfield(pso,'maxIter'), pso.maxIter = 60; end
if ~isfield(pso,'w'),       pso.w       = 0.7; end
if ~isfield(pso,'c1'),      pso.c1      = 1.6; end
if ~isfield(pso,'c2'),      pso.c2      = 1.6; end
if ~isfield(pso,'display'), pso.display = 'iter'; end

rng(1); % reproducible

x0 = x0(:);
nVar = numel(x0);

% ----- bounds -----
if isfield(opt,'bounds') && ~isempty(opt.bounds)
    lb = opt.bounds(1)*ones(nVar,1);
    ub = opt.bounds(2)*ones(nVar,1);
else
    lb = -inf(nVar,1);
    ub =  inf(nVar,1);
end

% ----- swarm init -----
X = repmat(x0.', pso.nSwarm, 1);          % nSwarm x nVar
V = zeros(pso.nSwarm, nVar);

% jitter around x0; robust to infinite bounds
spanRow = (ub - lb).';                     % 1 x nVar
spanRow(~isfinite(spanRow)) = 1;           % fallback scale
jitter = 0.2 .* randn(pso.nSwarm, nVar) .* repmat(spanRow, pso.nSwarm, 1);
X = X + jitter;

% clip to bounds
X = min(max(X, repmat(lb.', pso.nSwarm, 1)), repmat(ub.', pso.nSwarm, 1));

pbestX = X;                                % personal best positions
pbestJ = inf(pso.nSwarm,1);

bestJ = inf;                               % global best cost
bestX = x0;                                % global best position (column)

% ----- evaluate initial swarm -----
for i = 1:pso.nSwarm
    Ji = eval_lut_cost(pbestX(i,:).', opt);
    pbestJ(i) = Ji;
    if Ji < bestJ
        bestJ = Ji; bestX = pbestX(i,:).';
    end
end

histJ = zeros(pso.maxIter,1);
histJ(1) = bestJ;
if strcmpi(pso.display,'iter')
    fprintf('Iter %3d | Best J: %.6g\n', 1, bestJ);
end

% ----- main loop -----
for it = 2:pso.maxIter
    for i = 1:pso.nSwarm
        r1 = rand(1,nVar);
        r2 = rand(1,nVar);

        V(i,:) = pso.w*V(i,:) ...
               + pso.c1*r1.*(pbestX(i,:) - X(i,:)) ...
               + pso.c2*r2.*(bestX.'      - X(i,:));

        Xi = X(i,:).' + V(i,:).';          % column
        Xi = min(max(Xi, lb), ub);         % clip

        Ji = eval_lut_cost(Xi, opt);

        if Ji < pbestJ(i)
            pbestJ(i) = Ji;
            pbestX(i,:) = Xi.';
            if Ji < bestJ
                bestJ = Ji; bestX = Xi;
            end
        end

        X(i,:) = Xi.';                     % write back
    end

    histJ(it) = bestJ;
    if strcmpi(pso.display,'iter')
        fprintf('Iter %3d | Best J: %.6g\n', it, bestJ);
    end
end

bestX = bestX(:);                           % ensure column
end
