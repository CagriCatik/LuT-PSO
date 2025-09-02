% plot_pso_progress.m
if ~evalin('base','exist(''histJ'',''var'')')
    error('histJ not found. Run run_pso first.');
end
histJ = evalin('base','histJ');
it = 1:numel(histJ);

figure('Name','PSO Convergence','NumberTitle','off');
semilogy(it, histJ, '-o', 'LineWidth', 1.5, 'MarkerSize', 4);
grid on; xlim([1 numel(histJ)]);
xlabel('Iteration');
ylabel('Best J (semilogy)');
title('PSO Convergence: Best-so-far Cost');

% Optional: annotate final best
text(it(end), histJ(end), sprintf('  bestJ=%.3g', histJ(end)), 'VerticalAlignment','middle');

% Optional: save
% saveas(gcf, 'pso_convergence.png');
