function [bestX,bestJ,histJ] = pso_optimize_lut(x0,opt,pso)
%PSO_OPTIMIZE_LUT Basic particle swarm optimization for LUT vectors.

if nargin<3, pso=struct; end
defaults = struct('nSwarm',25,'maxIter',60,'w',0.7,'c1',1.6,'c2',1.6);
fn = fieldnames(defaults);
for k=1:numel(fn)
    if ~isfield(pso,fn{k}), pso.(fn{k}) = defaults.(fn{k}); end
end

x0 = x0(:); nVar = numel(x0);
if isfield(opt,'bounds')
    lb = opt.bounds(1)*ones(nVar,1);
    ub = opt.bounds(2)*ones(nVar,1);
else
    lb = -inf(nVar,1); ub = inf(nVar,1);
end

X = repmat(x0.',pso.nSwarm,1) + 0.2*randn(pso.nSwarm,nVar);
X = min(max(X,lb.'),ub.');
V = zeros(size(X));

pbestX = X; pbestJ = inf(pso.nSwarm,1);
bestJ = inf; bestX = x0;
for i=1:pso.nSwarm
    Ji = eval_lut_cost(pbestX(i,:).',opt);
    pbestJ(i) = Ji;
    if Ji < bestJ, bestJ=Ji; bestX=pbestX(i,:).'; end
end

histJ = zeros(pso.maxIter,1); histJ(1)=bestJ;
for it=2:pso.maxIter
    for i=1:pso.nSwarm
        r1 = rand(1,nVar); r2 = rand(1,nVar);
        V(i,:) = pso.w*V(i,:) + pso.c1*r1.*(pbestX(i,:)-X(i,:)) + ...
                 pso.c2*r2.*(bestX.'-X(i,:));
        Xi = X(i,:).' + V(i,:)';
        Xi = min(max(Xi,lb),ub);
        Ji = eval_lut_cost(Xi,opt);
        if Ji < pbestJ(i)
            pbestJ(i) = Ji; pbestX(i,:) = Xi';
            if Ji < bestJ, bestJ = Ji; bestX = Xi; end
        end
        X(i,:) = Xi';
    end
    histJ(it) = bestJ;
end
histJ = histJ(1:it);
bestX = bestX(:);
end
