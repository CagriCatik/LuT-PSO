# Simulink LUT Optimization with PSO

## Overview

This project builds a Simulink model and optimizes a 1-D Lookup Table (LUT) so the LUT output matches a target behavior with minimal mean squared error. A handwritten Particle Swarm Optimization (PSO) algorithm updates the LUT table values, runs the simulation, and minimizes the scalar cost produced by the model.

Objective minimized:

```matlab
J = (1/STOP_T) * integral_0^STOP_T ( y_ref(t) - y_lut(t) )^2 dt
```

Default reference mapping in the model:

```matlab
y_ref(u) = tanh(2*u)
```

## Repository Contents

* `build_mdl_lut.m`
  Creates `mdl_lut.slx` with sources, 1-D LUT, error path, time-normalized cost, and a To Workspace sink `J`.
* `eval_lut_cost.m`
  Sets a candidate LUT vector, runs the model, extracts `J` from `SimulationOutput` or base workspace, adds optional penalties.
* `pso_optimize_lut.m`
  Handwritten PSO that minimizes `J` by perturbing LUT values.
* `run_pso.m`
  Driver that configures options and PSO parameters, runs PSO, applies best LUT, and prints final metrics.

## Requirements

* MATLAB with Simulink.
* No toolboxes required beyond Simulink.
* Blocks used: Sine Wave, Fcn, 1-D Lookup Table, Sum, Math Function, Integrator, Product, To Workspace.

\[Unverified] Exact parameter availability may vary by MATLAB release.

## Installation

Place all `.m` files in a folder on the MATLAB path:

```matlab
addpath(genpath(pwd));
savepath;
```

## Quickstart

1. Build the model.

   ```matlab
   build_mdl_lut
   open_system('mdl_lut')  % optional
   ```

2. Smoke test the cost function.

   ```matlab
   opt.mdl = 'mdl_lut';
   opt.tblSize = size(evalin('base','TBL'));
   opt.bounds = [-2, 2];
   opt.lambda_mon = 0;
   opt.lambda_smooth = 1e-2;

   x0 = evalin('base','TBL(:)');
   J0 = eval_lut_cost(x0, opt);
   disp(['Baseline J: ' num2str(J0)]);
   ```

3. Run PSO.

   ```matlab
   run_pso
   ```

4. Validate statically on a grid.

   ```matlab
   BP   = evalin('base','BP');
   TBL  = evalin('base','TBL');
   uu   = linspace(min(BP), max(BP), 1000);
   y_ref = tanh(2*uu);
   y_lut = interp1(BP, TBL, uu, 'linear', 'extrap');
   mse_grid = mean((y_ref - y_lut).^2);
   fprintf('Grid MSE (static): %.6g\n', mse_grid);
   ```

## How It Works

* `build_mdl_lut` sets base variables and creates the model:

  * `STOP_T` simulation stop time.
  * `BP` breakpoints.
  * `TBL` LUT values, initialized to zeros.
  * Cost `J` is the normalized integral of squared error between reference and LUT outputs.

* `eval_lut_cost`:

  * Reshapes candidate vector `x` into `TBL`.
  * Simulates the model.
  * Extracts `J` as a scalar from numeric array, structure with time, timeseries, or Dataset.
  * Adds optional penalties:

    * Bounds: strong quadratic penalty outside `[lb, ub]`.
    * Monotonicity: penalizes negative first differences.
    * Smoothness: penalizes second differences.

* `pso_optimize_lut`:

  * Maintains a swarm of candidate vectors.
  * Updates positions and velocities using standard PSO rules.
  * Clips to bounds each step.
  * Tracks best-so-far `J` and position.

## Default Model Configuration

```matlab
STOP_T = 10;                % seconds
BP     = linspace(-1,1,11); % 11 breakpoints
TBL    = zeros(size(BP));   % LUT initial values
```

LUT settings: Linear interpolation, Clip extrapolation.

Reference block: `Expr = 'tanh(2*u)'`.

## Configuration

Edit `run_pso.m` or your driver script.

Bounds for LUT entries:

```matlab
opt.bounds = [-2, 2];
```

Regularization:

```matlab
opt.lambda_mon = 0;        % > 0 encourages nondecreasing table
opt.lambda_smooth = 1e-2;  % smoothness via second-difference penalty
```

PSO parameters:

```matlab
pso.nSwarm  = 25;
pso.maxIter = 60;
pso.w  = 0.7;
pso.c1 = 1.6;
pso.c2 = 1.6;
pso.display = 'iter';      % or 'off'
```

Change the reference function:

* Modify the Fcn block expression in `build_mdl_lut.m`:

  ```matlab
  'Expr','u./(1+abs(u))'   % example
  ```
* Re-run `build_mdl_lut`.

## Expected Results

* `bestJ` decreases over PSO iterations.
* The optimized `TBL` approximates the target mapping at breakpoints. For the default setup, `TBL` approaches `tanh(2*BP)`.

## Extending to 2-D or N-D LUTs

* Replace 1-D LUT with 2-D or N-D LUT blocks.
* Use `BP1, BP2, ...` and `TBL2D` or higher dimensional arrays.
* Flatten before optimization:

  ```matlab
  x = TBL2D(:);
  ```
* Reshape inside `eval_lut_cost` and assign to the block.
* Penalties:

  * Monotonicity along each axis via `diff(...,1,axis)`.
  * Smoothness via second differences per axis and summed.

## Performance Notes

* Fast Restart is enabled in `build_mdl_lut`.
* Reduce `STOP_T` to speed iterations if acceptable.
* Log only `J`.
* Rapid Accelerator may help in some releases. \[Unverified]
* Parallel evaluation is possible with `parsim` if runs are independent. \[Unverified]

## Troubleshooting

Error:

```
ToWorkspace block does not have a parameter named 'LimitDataPoints'
```

Fix: remove that parameter. Use `VariableName`, `SaveFormat`, `Decimation`, `SampleTime`.

Error:

```
Unrecognized function or variable 'J'.
```

Causes: To Workspace `VariableName` mismatch, unexpected `SaveFormat`, or outputs not returned. Fix:

```matlab
set_param('mdl_lut/J_to_ws','VariableName','J','SaveFormat','Array');
set_param('mdl_lut','ReturnWorkspaceOutputs','on');  % if available
```

Error:

```
Unrecognized field name 'has'.
```

Cause: `SimulationOutput.has` not available in your release. Fix: use `who(simOut)` and `simOut.get('J')`, else fall back to base workspace.

Error:

```
Arrays have incompatible sizes for this operation.
```

Cause: jitter replication mismatch. Fix: use the corrected jitter block in `pso_optimize_lut.m` that builds a `nSwarm x nVar` matrix and clips with replicated bounds.

No decrease in J:

* Increase input excitation range or amplitude.
* Relax bounds.
* Reduce regularization temporarily.
* Increase `nSwarm` or `maxIter`.

## API Summary

### build\_mdl\_lut

Creates `mdl_lut.slx`, sets base variables, enables Fast Restart.

### eval\_lut\_cost

Inputs: `x` (column), `opt` struct.
Output: scalar `J`.

### pso\_optimize\_lut

Inputs: `x0`, `opt`, optional `pso`.
Outputs: `bestX`, `bestJ`, `histJ`.

### run\_pso

Configures `opt` and `pso`, runs optimization, applies best LUT, prints final metrics.


