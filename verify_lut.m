function verify_lut()
%VERIFY_LUT Compare LUT output to reference and plot convergence.

BP  = evalin('base','BP');
TBL = evalin('base','TBL');
ref = @(u) tanh(2*u);

Tref = ref(BP);
figure('Name','Breakpoints','NumberTitle','off');
plot(BP,Tref,'-o',BP,TBL,'-x');
legend('target','LUT'); grid on;
xlabel('u'); ylabel('y'); title('Breakpoint comparison');

uu = linspace(min(BP),max(BP),1000);
y_ref = ref(uu);
y_lut = interp1(BP,TBL,uu,'linear','extrap');
figure('Name','Static Sweep','NumberTitle','off');
plot(uu,y_ref,'-',uu,y_lut,'--');
legend('y_{ref}','y_{lut}'); grid on;
xlabel('u'); ylabel('y'); title('Static sweep');
mse_grid = mean((y_ref-y_lut).^2);
fprintf('Grid MSE (static): %.6g\n',mse_grid);

if evalin('base','exist(''histJ'',''var''))
    histJ = evalin('base','histJ');
    it = 1:numel(histJ);
    figure('Name','PSO Convergence','NumberTitle','off');
    semilogy(it,histJ,'-o'); grid on;
    xlabel('Iteration'); ylabel('Best J');
    title('PSO convergence');
end
end
