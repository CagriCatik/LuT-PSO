# Simulink LUT Optimization With Handwritten PSO

## 1. Overview

This package builds a Simulink model and optimizes a 1-D Lookup Table (LUT) so the LUT output tracks a target behavior with minimal mean-squared error (MSE). 
A Particle Swarm Optimization (PSO) algorithm updates the LUT table values, runs the simulation, and minimizes the scalar cost exported from the model.

Primary goal: minimize

```
J = (1/STOP_T) * integral_0^STOP_T ( y_ref(t) - y_lut(t) )^2 dt
```

where `y_ref(t)` is a reference mapping of the input signal and `y_lut(t)` is the 1-D LUT output with linear interpolation and clipped extrapolation.

## 2. Files

* `build_mdl_lut.m`
  Programmatically creates `mdl_lut.slx` with:

  * Sine input `u(t)`
  * Reference function block `y_ref = tanh(2*u)` (editable)
  * 1-D LUT block parameterized by workspace variables `BP` and `TBL`
  * Error, square, integrator, normalization `(1/STOP_T)`, and a To Workspace sink `J`

* `eval_lut_cost.m`
  Sets candidate LUT values, runs the simulation, reads `J` from `SimulationOutput` or base workspace, and adds optional penalties (bounds, monotonicity, smoothness).

* `pso_optimize_lut.m`
  Handwritten PSO that iteratively calls `eval_lut_cost` to minimize `J`.

* `run_pso.m`
  Driver that configures options and PSO parameters, runs the optimization, applies the best LUT back to the workspace, and prints final metrics.



## 5. Model Architecture

Blocks and signals:

* `u(t)`: Sine Wave source. Default amplitude 1, frequency 1 rad/s, sample time 0 (continuous).
* `y_ref = f(u)`: Fcn block. Default `tanh(2*u)`. Replace the `Expr` parameter to change the target.
* `y_lut = LUT(u)`: 1-D Lookup Table with:

  * Breakpoints: `BP` (vector in base workspace)
  * Table data: `TBL` (vector, same length as `BP`)
  * Interpolation: Linear
  * Extrapolation: Clip
* Error and cost:

  * `e = y_ref - y_lut`
  * `e^2` via Math Function (square)
  * Integrator accumulates `int e^2 dt`
  * Constant `1/STOP_T` multiplies the integrated error to get time-normalized MSE
  * To Workspace `J` (SaveFormat = Array) outputs a scalar time series; the last sample is used as the scalar cost

Model parameters in base workspace:

```matlab
STOP_T = 10;             % simulation stop time [s]
BP     = linspace(-1,1,11);
TBL    = zeros(size(BP));
```

## 6. Cost Function

`eval_lut_cost(x, opt)` computes:

```
J_total = J_sim + penalties
```

* `x` is the candidate LUT vector. It is reshaped to `opt.tblSize` and assigned to `TBL`.
* `sim(opt.mdl)` runs with Fast Restart enabled by the build script.
* `J_sim` is the final scalar from `J`:

  * Numeric array: `J_sim = J(end)`
  * Structure with time: `J_sim = J.signals.values(end)`
  * `timeseries` or `Dataset`: last data sample
* Optional penalties:

  * Bounds (soft box):

    ```
    pen_bounds = 1e6 * sum( max(0, TBL-ub).^2 + max(0, lb-TBL).^2 )
    ```
  * Monotonicity:

    ```
    pen_mon = lambda_mon * sum( max(0, -diff(TBL(:))) )
    ```
  * Smoothness:

    ```
    pen_smooth = lambda_smooth * sum( diff(TBL(:),2).^2 )
    ```

## 7. PSO Algorithm

Core update per particle `i`:

```
v_i = w*v_i + c1*rand().*(pbest_i - x_i) + c2*rand().*(gbest - x_i)
x_i = clip( x_i + v_i, lb, ub )
```

* Initialization: swarm samples around the initial guess `x0` with small Gaussian jitter and is clipped to bounds.
* Personal bests and global best are updated on improvement.
* History `histJ(it)` tracks best-so-far cost for each iteration.

Default PSO parameters:

```
nSwarm = 25
maxIter = 60
w  = 0.7
c1 = 1.6
c2 = 1.6
```

## 8. Usage Scenarios

* Static approximation: LUT approximates a known mapping `y_ref = f(u)`. With sufficient input excitation and no penalties, the best LUT samples the target at breakpoints:

  ```
  TBL* = f(BP)
  ```

  \[Inference] Weighting by how often `u` visits each region can slightly bias the fit.

* System-level tuning: The LUT feeds a dynamic plant, and `J` measures closed-loop performance (tracking, energy, constraints). PSO searches table values that optimize the overall behavior without requiring gradients.

* Constrained shaping: Enforce monotone LUTs and smooth surfaces via penalties.

## 9. Configuration

Edit these in `run_pso.m` or your own driver:

* Bounds for LUT entries:

```matlab
opt.bounds = [-2, 2];
```

* Regularization:

```matlab
opt.lambda_mon = 0;       % >0 encourages nondecreasing table
opt.lambda_smooth = 1e-2; % smoothness via second-difference penalty
```

* PSO tuning:

```matlab
pso.nSwarm  = 25;
pso.maxIter = 60;
pso.w  = 0.7; pso.c1 = 1.6; pso.c2 = 1.6;
pso.display = 'iter';     % or 'off'
pso.tolFun    = 1e-6;     % early stop tolerance on best J improvement
pso.stallIter = 10;       % number of stagnant iterations before stop
```

* Reference function: change `Expr` in `build_mdl_lut.m`:

```matlab
% Example: cubic saturation-like
'Expr','u./(1+abs(u))'
```

Rebuild the model after changing the expression.

## 10. Validation

Static curve check:

```matlab
BP   = evalin('base','BP');
TBL  = evalin('base','TBL');
uu   = linspace(min(BP), max(BP), 1000);
y_ref = tanh(2*uu);
y_lut = interp1(BP, TBL, uu, 'linear', 'extrap');

figure; plot(BP, tanh(2*BP), '-o'); hold on;
plot(BP, TBL, '-x'); grid on;
legend('target tanh(2*BP)','optimized TBL');
xlabel('u'); ylabel('y'); title('LUT vs. target at breakpoints');

mse_grid = mean((y_ref - y_lut).^2);
fprintf('Grid MSE (static): %.6g\n', mse_grid);
```

Simulation check:

* `run_pso` prints `Best J` during optimization and a final `J` after applying the best table.
* Expect `Best J` to decrease over iterations.

## 11. Extending to 2-D/ND LUTs

* Replace 1-D LUT with 2-D Lookup Table.
* Workspace variables:

  ```
  BP1, BP2
  TBL2D (size length(BP1) x length(BP2))
  ```
* Flatten/reshape:

  ```
  x = TBL2D(:);
  TBL2D = reshape(x, [numel(BP1), numel(BP2)]);
  ```
* In `eval_lut_cost`, reshape to matrix and set block table accordingly.
* Penalties:

  * Monotonicity per axis:

    ```
    pen_mon = sum(max(0, -diff(TBL2D,1,1)), 'all') + sum(max(0, -diff(TBL2D,1,2)), 'all');
    ```
  * Smoothness via 2-D Laplacian-like terms:

    ```
    pen_smooth = sum( diff(TBL2D,2,1).^2, 'all') + sum( diff(TBL2D,2,2).^2, 'all');
    ```

## 12. Optimizing Breakpoints

* Decision vector can include both table values and breakpoints.
* Keep breakpoints strictly increasing:

  * Parameterize with cumulative positive steps, or
  * Add strong penalties for non-monotone `BP`.
* Update the LUT block parameters for breakpoints each evaluation.
* Use tighter bounds and stronger smoothness to avoid overfitting.

## 13. Performance Tips

* Fast Restart is enabled by the build script:

  ```
  set_param('mdl_lut','FastRestart','on');
  ```
* Keep `StopTime` as small as possible while representative:

  ```
  STOP_T = 5;  % faster iterations if acceptable
  ```
* Minimize logging: only `J` is exported.
* Reduce swarm size or iterations for quick tests; increase for harder problems.
* Rapid Accelerator can speed up repeated runs in some releases:

  ```
  set_param('mdl_lut','SimulationMode','rapid-accelerator');
  ```

  \[Unverified] Availability and gains vary by release and model structure.
* Parallelization: batch-evaluate particles with `parsim` if the cost is independent across runs. \[Unverified] Requires Parallel Computing Toolbox and model independence.

## 14. Troubleshooting

Error:
`ToWorkspace block does not have a parameter named 'LimitDataPoints'`
Fix: remove that parameter. Valid parameters include `VariableName`, `SaveFormat`, `Decimation`, `SampleTime`.

Error:
`Unrecognized function or variable 'J'.`
Causes: the To Workspace block name or `VariableName` mismatched, `SaveFormat` unexpected, or outputs not returned.
Fixes:

```matlab
set_param('mdl_lut/J_to_ws','VariableName','J','SaveFormat','Array');
set_param('mdl_lut','ReturnWorkspaceOutputs','on'); % if available
```

Then re-run `sim`.

Error:
`Unrecognized field name "has".`
Cause: `SimulationOutput.has` is not present in your release.
Fix: detect variables with `who(simOut)` and use `simOut.get('J')` when listed; otherwise, fall back to base workspace.

Error:
`Arrays have incompatible sizes for this operation.` in PSO init
Cause: mismatched jitter replication.
Fix: use the corrected jitter block in `pso_optimize_lut.m` (already provided).

No decrease in `J`:

* Verify the input excites the relevant LUT range; increase amplitude or sweep inputs.
* Relax bounds if too tight.
* Lower `lambda_smooth` or turn off monotonicity temporarily.
* Increase `nSwarm` or `maxIter`.

## 15. API Reference

### 15.1 build\_mdl\_lut

Creates and saves `mdl_lut.slx`. Sets:

* `STOP_T` in base workspace.
* `BP`, `TBL` in base workspace.
* Model with To Workspace `J` (SaveFormat = Array).

Signature:

```
build_mdl_lut()
```

Postconditions:

* Model exists on disk.
* `FastRestart` enabled.

### 15.2 eval\_lut\_cost

Inputs:

* `x` (column vector): candidate LUT values.
* `opt` (struct):

  * `mdl`         : model name (e.g., 'mdl\_lut')
  * `tblSize`     : size of LUT array (e.g., `size(TBL)`)
  * `bounds`      : `[lb ub]` numeric (optional)
  * `lambda_mon`  : nonnegative scalar (optional)
  * `lambda_smooth`: nonnegative scalar (optional)

Output:

* `J` (double): scalar objective.

### 15.3 pso\_optimize\_lut

Inputs:

* `x0`  : initial LUT vector (`TBL(:)`)
* `opt` : as above
* `pso` : optional struct

  * `nSwarm`, `maxIter`, `w`, `c1`, `c2`, `display`

Outputs:

* `bestX` : best LUT vector found (column)
* `bestJ` : best objective scalar
* `histJ` : best-so-far history per iteration

### 15.4 run\_pso

Driver script. Configures `opt` and `pso`, runs PSO, writes best table to base workspace, simulates once more, and prints final `J`.

## 16. Interpreting Results

* `bestJ` printed during optimization: best-so-far simulation MSE at that iteration (plus penalties if configured).
* `Final J` after applying `bestX`: confirms consistency.
* Plot of `TBL` vs `tanh(2*BP)`: curves should be close for the default reference.
* Static grid MSE (`mse_grid`): provides a sampling-based check independent of the time signal.

## 17. Known Limitations

* The objective is as good as the excitation. If `u(t)` does not traverse portions of `BP`, the fit there is weak.
* Smoothness and monotonicity penalties trade off bias vs. variance; heavy penalties can underfit.
* PSO is stochastic; different seeds can yield slightly different solutions. Set `rng(1)` for reproducibility.
* Handwritten PSO is not gradient-based; convergence speed depends on settings and problem conditioning.

## 18. Change Reference Targets

To approximate a different static mapping:

* Edit the Fcn block expression in `build_mdl_lut.m`:

  ```
  'Expr','<your_expression_in_u>'
  ```
* Rebuild the model with `build_mdl_lut`.
* Re-run `run_pso`.

## 19. Appendix: Minimal Plots

Breakpoint comparison:

```matlab
BP  = evalin('base','BP');
TBL = evalin('base','TBL');
plot(BP, tanh(2*BP), '-o'); hold on; plot(BP, TBL, '-x'); grid on;
legend('target','LUT'); xlabel('u'); ylabel('y');
```

Error over time:

```matlab
simOut = sim('mdl_lut');
J = simOut.get('J'); 
% If numeric array:
plot(J); grid on; xlabel('sample'); ylabel('J'); title('Cost time series');
```


