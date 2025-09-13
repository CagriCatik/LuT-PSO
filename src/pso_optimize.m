function [bestX, bestJ, histJ] = pso_optimize(costFcn, x0, pso, bounds)
% Generic PSO with early stopping.
% costFcn(x) -> scalar cost
% x0: column vector initial guess
% pso: struct with fields nSwarm,maxIter,w,c1,c2,display,tolFun,stallIter
% bounds: [min max] or [] for unbounded

% Defaults
if nargin < 3 || isempty(pso), pso = struct; end
if ~isfield(pso,'nSwarm'),    pso.nSwarm    = 25; end
if ~isfield(pso,'maxIter'),   pso.maxIter   = 60; end
if ~isfield(pso,'w'),         pso.w         = 0.7; end
if ~isfield(pso,'c1'),        pso.c1        = 1.6; end
if ~isfield(pso,'c2'),        pso.c2        = 1.6; end
if ~isfield(pso,'display'),   pso.display   = 'iter'; end
if ~isfield(pso,'tolFun'),    pso.tolFun    = 1e-6; end
if ~isfield(pso,'stallIter'), pso.stallIter = 10; end

rng(1);  % reproducible

x0 = x0(:);
nVar = numel(x0);

if nargin < 4 || isempty(bounds)
    lb = -inf(nVar,1); ub = inf(nVar,1);
else
    lb = bounds(1)*ones(nVar,1);
    ub = bounds(2)*ones(nVar,1);
end

% Initialize swarm
X = repmat(x0.', pso.nSwarm, 1);
V = zeros(pso.nSwarm, nVar);

spanRow = (ub - lb).'; spanRow(~isfinite(spanRow)) = 1;
jitter = 0.2 .* randn(pso.nSwarm, nVar) .* repmat(spanRow, pso.nSwarm, 1);
X = X + jitter;
X = min(max(X, repmat(lb.', pso.nSwarm, 1)), repmat(ub.', pso.nSwarm, 1));

pbestX = X;
pbestJ = inf(pso.nSwarm,1);
bestJ  = inf;
bestX  = x0;

% Evaluate initial swarm
for i = 1:pso.nSwarm
    Ji = costFcn(pbestX(i,:).');
    pbestJ(i) = Ji;
    if Ji < bestJ
        bestJ = Ji;
        bestX = pbestX(i,:).';
    end
end

histJ = zeros(pso.maxIter,1);
histJ(1) = bestJ;
if strcmpi(pso.display,'iter')
    fprintf('Iter %3d | Best J: %.6g\n', 1, bestJ);
end

stallCount = 0;
prevBestJ  = bestJ;
lastIt     = 1;

% Main loop
for it = 2:pso.maxIter
    for i = 1:pso.nSwarm
        r1 = rand(1,nVar);
        r2 = rand(1,nVar);
        V(i,:) = pso.w*V(i,:) ...
               + pso.c1*r1.*(pbestX(i,:) - X(i,:)) ...
               + pso.c2*r2.*(bestX.'      - X(i,:));
        Xi = X(i,:).' + V(i,:).';
        Xi = min(max(Xi, lb), ub);
        Ji = costFcn(Xi);
        if Ji < pbestJ(i)
            pbestJ(i) = Ji;
            pbestX(i,:) = Xi.';
            if Ji < bestJ
                bestJ = Ji;
                bestX = Xi;
            end
        end
        X(i,:) = Xi.';
    end

    histJ(it) = bestJ;
    if strcmpi(pso.display,'iter')
        fprintf('Iter %3d | Best J: %.6g\n', it, bestJ);
    end

    if abs(prevBestJ - bestJ) < pso.tolFun
        stallCount = stallCount + 1;
    else
        stallCount = 0;
    end
    prevBestJ = bestJ;
    lastIt = it;

    if stallCount >= pso.stallIter
        if strcmpi(pso.display,'iter')
            fprintf('Stopping early after %d stagnant iterations.\n', stallCount);
        end
        break;
    end
end

histJ = histJ(1:lastIt);
bestX = bestX(:);
end
