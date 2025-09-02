% verify_and_convergence.m
% 1) LUT vs. analytic target at breakpoints
% 2) Static sweep error metrics
% 3) PSO convergence: iteration vs. best J

% --- Preconditions ---
if ~evalin('base','exist(''BP'',''var'')')
    error('BP not found in base workspace. Run build_mdl_lut or initialize BP.');
end
if ~evalin('base','exist(''TBL'',''var'')')
    error('TBL not found in base workspace. Run run_pso or initialize TBL.');
end

% ======================
% 1. Compare at breakpoints
% ======================
BP   = evalin('base','BP');
TBL  = evalin('base','TBL');           % current (optimized) table
Tref = tanh(2*BP);                     % analytic target for this model

figure('Name','Breakpoints','NumberTitle','off');
plot(BP, Tref, '-o', 'LineWidth', 1.5); hold on;
plot(BP, TBL,  '-x', 'LineWidth', 1.5);
legend('target tanh(2*BP)','optimized TBL','Location','best');
grid on; xlabel('u'); ylabel('y');
title('Breakpoint vs. Table Values');

% ======================
% 2. Static sweep (dense grid)
% ======================
uu    = linspace(min(BP), max(BP), 1000);
y_ref = tanh(2*uu);
y_lut = interp1(BP, TBL, uu, 'linear', 'extrap');  % matches Simulink LUT settings

err       = y_ref - y_lut;
mse_grid  = mean(err.^2);
fprintf('Grid MSE (static): %.6g\n', mse_grid);

figure('Name','Static Sweep','NumberTitle','off');
plot(uu, y_ref, '-',  'LineWidth', 1.5); hold on;
plot(uu, y_lut, '--', 'LineWidth', 1.5);
legend('y_{ref}(u)','y_{lut}(u)','Location','best');
grid on; xlabel('u'); ylabel('y');
title('Static Sweep Comparison');

% ======================
% 3. PSO convergence plot: iteration vs. best J
% ======================
if ~evalin('base','exist(''histJ'',''var'')')
    error('histJ not found. Run run_pso first (and ensure it assigns histJ to base).');
end
histJ = evalin('base','histJ');
it = 1:numel(histJ);

figure('Name','PSO Convergence','NumberTitle','off');
semilogy(it, histJ, '-o', 'LineWidth', 1.5, 'MarkerSize', 4);
grid on; xlim([1 numel(histJ)]);
xlabel('Iteration');
ylabel('Best J (semilogy)');
title('PSO Convergence: Best-so-far Cost');

% Annotate final best
text(it(end), histJ(end), sprintf('  bestJ=%.3g', histJ(end)), 'VerticalAlignment','middle');

% Optional: save figures
saveas(gcf, 'pso_convergence.png');
