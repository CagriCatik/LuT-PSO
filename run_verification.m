% 1) Compare best table to analytic target at breakpoints
BP   = evalin('base','BP');
TBL  = evalin('base','TBL');         % current (optimized) table
Tref = tanh(2*BP);                   % analytic target for this model

figure; 
plot(BP,Tref,'-o'); hold on;
plot(BP,TBL,'-x');
legend('target tanh(2*BP)','optimized TBL'); grid on; xlabel('u'); ylabel('y');
title('Breakpoint vs. Table Values');

% 2) Static sweep to compare curves (dense grid)
uu = linspace(min(BP), max(BP), 1000);
y_ref = tanh(2*uu);
y_lut = interp1(BP, TBL, uu, 'linear', 'extrap');  % matches Simulink LUT settings
mse_grid = mean((y_ref - y_lut).^2);
fprintf('Grid MSE (static): %.6g\n', mse_grid);

% 3) Simulation MSE (already printed as bestJ/final J)
