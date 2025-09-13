function mse_grid = verify_lut_results(BP, TBL, target_fun, histJ)
% Plots:
%   1) Breakpoint comparison
%   2) Static sweep
%   3) PSO convergence (if histJ provided)
% Returns:
%   mse_grid from static sweep on dense grid.

% 1) Breakpoints
Tref = target_fun(BP);
figure('Name','Breakpoints','NumberTitle','off');
plot(BP, Tref, '-o', 'LineWidth', 1.5); hold on;
plot(BP, TBL,  '-x', 'LineWidth', 1.5);
legend('target f(BP)','optimized TBL','Location','best');
grid on; xlabel('u'); ylabel('y'); title('Breakpoint vs. Table Values');

% 2) Static sweep
uu    = linspace(min(BP), max(BP), 1000);
y_ref = target_fun(uu);
y_lut = interp1(BP, TBL, uu, 'linear', 'extrap');
err   = y_ref - y_lut;
mse_grid = mean(err.^2);
fprintf('Grid MSE (static): %.6g\n', mse_grid);

figure('Name','Static Sweep','NumberTitle','off');
plot(uu, y_ref, '-',  'LineWidth', 1.5); hold on;
plot(uu, y_lut, '--', 'LineWidth', 1.5);
legend('y_ref(u)','y_lut(u)','Location','best');
grid on; xlabel('u'); ylabel('y'); title('Static Sweep Comparison');

% 3) Convergence
if nargin >= 4 && ~isempty(histJ)
    it = 1:numel(histJ);
    figure('Name','PSO Convergence','NumberTitle','off');
    semilogy(it, histJ, '-o', 'LineWidth', 1.5, 'MarkerSize', 4);
    grid on; xlim([1 numel(histJ)]);
    xlabel('Iteration'); ylabel('Best J (semilogy)');
    title('PSO Convergence: Best-so-far Cost');
    text(it(end), histJ(end), sprintf('  bestJ=%.3g', histJ(end)), 'VerticalAlignment','middle');
end
end
