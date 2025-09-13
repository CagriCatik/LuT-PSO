# Simulink LUT Optimization with PSO

This project provides an end-to-end workflow for optimizing a 1-D lookup table (LUT) in Simulink using a custom Particle Swarm Optimization (PSO) algorithm. It automates model setup, cost evaluation, optimization, and verification while exporting artifacts for reproducibility. The framework supports any Simulink model that outputs a scalar cost, with default configurations for breakpoints, table values, and reference functions. Key features include penalty terms for monotonicity and smoothness, early stopping for convergence, reproducible results with fixed seeds, and visualization of performance through plots and summaries. The modular structure separates responsibilities across setup, optimization, evaluation, and result management, making it extensible to higher-dimensional LUTs.

---

## Goal and Objective Function

* Tune LUT values `TBL` so the model minimizes a scalar cost `J` that your Simulink model computes.
* A common cost is the time-normalized MSE between a reference mapping and the LUT output:

  ```matlab
  J = (1/STOP_T) * integral_0^STOP_T ( y_ref(t) - y_lut(t) )^2 dt
  ```

* Verification defaults to:

  ```matlab
  y_ref(u) = tanh(2*u)
  ```

Any model that emits a scalar `J` is supported.

---

## Repository Layout

```sh
LuT-PSO/
├─ run_all.m
├─ src/
│  ├─ find_and_load_model.m
│  ├─ prepare_model_and_workspace.m
│  ├─ optimize_lut_pso.m
│  ├─ pso_optimize.m
│  ├─ eval_lut_cost.m
│  ├─ sim_read_J.m
│  ├─ verify_lut_results.m
│  ├─ save_plot.m
│  ├─ save_new_figures.m
│  └─ sanitize_filename.m
└─ artifacts/                (created at runtime)
```

**Notes:**

* Provide your own model (e.g., `mdl_lut.slx`) that consumes `BP` and `TBL` from the base workspace and emits `J`.
* The loader searches the MATLAB path and the current folder tree.

---

## Requirements and Model Contract

Software:

* MATLAB with Simulink.
* Standard Simulink blocks only.
* No extra toolboxes required beyond Simulink.

Model contract:

* Reads `BP` (1xN or Nx1) and `TBL` (1xN or Nx1, same length) from base workspace into a 1-D Lookup Table block.
* Emits scalar `J` accessible via:

  * To Workspace block with `VariableName = 'J'`, `SaveFormat = 'Array'`, or
  * `SimulationOutput` entry named `J`, or
  * A `timeseries` or `Dataset` convertible to a scalar by taking the final data sample.

* Default workspace initialization if missing:

  ```matlab
  STOP_T = 10;
  BP     = linspace(-1,1,11);
  TBL    = zeros(size(BP));
  ```

---

## Installation

* Add the project to the MATLAB path:

  ```matlab
  addpath(genpath('C:\path\to\LuT-PSO'))
  savepath  % optional
  ```

* Ensure your model file (e.g., `mdl_lut.slx`) is reachable on the path or under your working directory.

---

## Quick Start

* From MATLAB:

  ```matlab
  cd C:\path\to\LuT-PSO
  run_all
  ```

What happens:

* The script locates and loads your model.
* It validates or initializes `STOP_T`, `BP`, `TBL`.
* It runs PSO to minimize `J` by tuning `TBL`.
* It simulates the model with the best `TBL`, plots verification figures, and saves artifacts to:

  ```matlab
  artifacts\YYYYMMDD_HHMMSS\
  ```

---

## Configuration (in `run_all.m`)

```matlab
cfg.mdl            = 'mdl_lut';      % Simulink model name
cfg.bounds         = [-2 2];         % clamp for LUT values
cfg.lambda_mon     = 0;              % monotonicity penalty weight
cfg.lambda_smooth  = 1e-2;           % smoothness penalty weight
cfg.target_fun     = @(u) tanh(2*u); % verification-only reference mapping

cfg.pso.nSwarm     = 50;             % swarm size
cfg.pso.maxIter    = 120;            % max iterations
cfg.pso.w          = 0.7;            % inertia
cfg.pso.c1         = 1.6;            % cognitive weight
cfg.pso.c2         = 1.6;            % social weight
cfg.pso.display    = 'iter';         % 'iter' or 'none'
cfg.pso.tolFun     = 1e-6;           % early stop threshold on |delta bestJ|
cfg.pso.stallIter  = 10;             % early stop patience

open_model_window  = true;           % false for headless runs
```

Recommended model settings applied automatically:

* `FastRestart` on
* `ReturnWorkspaceOutputs` on
* Optional block param attempt: `[mdl '/J_to_ws']` set to write `J` (ignored if absent)

---

## Pipeline and File Responsibilities

* `find_and_load_model.m`
   Locates and loads `cfg.mdl` from the MATLAB path or by recursive search under the current folder.

* `prepare_model_and_workspace.m`
   Ensures `STOP_T`, `BP`, `TBL` exist in base workspace and applies preferred model settings.

* `optimize_lut_pso.m`
   Builds `opt` and calls `pso_optimize` with `eval_lut_cost` as the objective. Applies best `TBL`, simulates once more, prints `bestJ` and `J_final`.

* `pso_optimize.m`
   Handwritten PSO with bounds and early stopping.

* `eval_lut_cost.m`
   Reshapes `x` to `TBL`, clamps to bounds, runs `sim`, reads `J` via `sim_read_J`, adds penalties, returns scalar cost.

* `verify_lut_results.m`
   Generates:

  * Breakpoints plot: `TBL` vs `cfg.target_fun(BP)`
  * Static sweep plot (`interp1` linear, extrap enabled)
  * PSO convergence plot (semilog y) from `histJ`

* `save_plot.m` and `save_new_figures.m`
   Persist figures as `.png` and `.fig` into the timestamped `artifacts` subfolder.

---

## Objective, Penalties, and Bounds

Total cost:

```matlab
J_total = J_sim + pen_mon + pen_smooth
```

Where:

* `J_sim` is extracted by `sim_read_J` as the final numeric sample from one of:

  * Numeric array, `timeseries`, structure-with-time, or dataset.
* Monotonicity penalty:

  ```matlab
  pen_mon = lambda_mon * sum( max(0, -diff(TBL(:))).^2 )
  ```

* Smoothness penalty:

  ```matlab
  pen_smooth = lambda_smooth * sum( diff(TBL(:),2 ).^2 )
  ```

* Bounds on `TBL` are enforced by clamping before simulation:

  ```matlab
  TBL = min(max(TBL, lb), ub);
  ```

If `J` cannot be read, a heavy penalty `1e12` is returned to ensure the search avoids invalid settings.

---

## PSO Details

* State update for particle `i`:

  ```matlab
  v_i = w*v_i + c1*rand().*(pbest_i - x_i) + c2*rand().*(gbest - x_i)
  x_i = clip( x_i + v_i, lb, ub )
  ```

* Implementation notes:

  * Initialization uses small Gaussian jitter around `x0`, clipped to bounds.
  * Personal bests and global best track the best observed cost.
  * History `histJ` stores global best per iteration.
  * Reproducibility: `rng(1)` inside PSO for deterministic runs.

* Early stopping:

  * Triggered when `abs(delta bestJ) < tolFun` for `stallIter` consecutive iterations.
  * Absolute improvement, not relative.

---

## Verification Metrics and Outputs

* Breakpoints plot: compares `TBL` vs `cfg.target_fun(BP)`.
* Static sweep:

  ```matlab
  uu    = linspace(min(BP), max(BP), 1000);
  y_ref = cfg.target_fun(uu);
  y_lut = interp1(BP, TBL, uu, 'linear', 'extrap');
  mse_grid = mean((y_ref - y_lut).^2);
  ```

* Convergence plot: semilog of `histJ`.

Console summary after `run_all`:

* `Best J (PSO)`
* `Final J (sim with best TBL)`
* `Grid MSE (static)`

Artifacts:

* `.png` and `.fig` copies of figures saved to `artifacts\YYYYMMDD_HHMMSS\`.

---

## Step-by-Step Usage Guide

* Prepare the model:

* Ensure the model uses `BP` and `TBL` from base workspace for its 1-D LUT.
* Ensure the model emits a scalar `J` via To Workspace or `SimulationOutput`.

* Configure and run:

```matlab
cd C:\path\to\LuT-PSO
open run_all.m
% adjust cfg.* as needed
run_all
```

* Inspect outputs:

* Check Command Window for `Best J`, `Final J`, `mse_grid`.
* Open figures for breakpoints, static sweep, convergence.
* Review saved files under `artifacts\...`.

* Iterate:

* Tune `cfg.pso` parameters, `cfg.bounds`, `cfg.lambda_*`, and your model signals to improve convergence.

---

## Practical Tuning Guidelines

Exploration vs exploitation:

* Increase `w` for more inertia; increase `c1`/`c2` to accelerate toward bests.
* Use larger `nSwarm` for broader search; increase `maxIter` to refine.

Regularization:

* Increase `lambda_smooth` to damp oscillatory tables.
* Increase `lambda_mon` to enforce nondecreasing behavior.

Bounds:

* Start wide to explore; tighten when the solution stabilizes.

Excitation:

* Ensure the model input traverses the LUT range used. If `u` rarely visits certain regions, the fit there will be poor.

Speed:

* Reduce `STOP_T` if acceptable.
* Lower `nSwarm` or `maxIter` during prototyping, then scale up.

Acceleration:

* Rapid Accelerator or parallel evaluation may help. \[Unverified]

---

## Extending Beyond 1-D LUTs

For 2-D or N-D LUTs:

* Use `BP1, BP2, ...` and a multi-D table `TBLND`.
* Flatten to a vector for optimization: `x = TBLND(:)`.
* Reshape inside `eval_lut_cost` and assign to the base workspace variable consumed by your model.
* Extend penalties per axis:

  * Monotonicity: negative first differences along each dimension.
  * Smoothness: second differences along each dimension, summed.

> Multi-D support requires adapting your model’s LUT block configuration and `eval_lut_cost` reshape logic.

---

## Reproducibility and Logging

* PSO sets `rng(1)` for deterministic results. Change the seed to explore variety.
* Limit logging to `J` for speed.
* Figures are versioned by timestamp. Keep a run log by saving `histJ` and `TBL_best` to MAT files if needed:

  ```matlab
  save(fullfile(outDir,'results.mat'),'TBL_best','bestJ','J_final','histJ');
  ```

---

## Troubleshooting

**Undefined model:**

* Set `cfg.mdl` correctly and ensure the file is reachable.
* The loader searches both the MATLAB path and the current folder tree.
* Error: expected a string scalar or character vector for parameter name:

* Ensure any custom `set_param` calls use char vectors for block paths and parameter names. Internal code converts model names to char.

**No `J` found:**

* Add a To Workspace block with `VariableName = 'J'` and `SaveFormat = 'Array'`, or ensure `J` exists in `SimulationOutput`. `sim_read_J` supports several formats.

**Size mismatch for `TBL`:**

* Ensure `numel(TBL) == numel(BP)`. The runner initializes them consistently.

**No decrease in `J`:**

* Increase input excitation.
* Loosen `bounds`, reduce penalties temporarily.
* Increase `nSwarm` or `maxIter`.

**Slow runs:**

* Reduce `STOP_T`, reduce `nSwarm` or `maxIter`.
* Consider Accelerator modes. \[Unverified]

---

## Security and Safety Considerations

* This project assigns `BP` and `TBL` into the base workspace and reads `J` back.
* Avoid name collisions with unrelated variables.
* Avoid using `eval` in your model wherever possible.
* Use parameterized blocks and To Workspace sinks.

## Primary Parameters and Results

Here is the meaning of each variable in the LUT–PSO optimization workflow:

### **BP**

* Breakpoints of the LUT.
* A vector in the base workspace that defines the x-axis locations where the LUT samples are placed.
* Example default:

  ```matlab
  BP = linspace(-1,1,11);   % 11 breakpoints from -1 to 1
  ```

### TBL

* Table data corresponding to `BP`.
* A vector of the same length as `BP` that holds the LUT output values at those breakpoints.
* Example default:

  ```matlab
  TBL = zeros(size(BP));    % initialized to zeros
  ```

### TBL\_best

* The optimized LUT table values found by PSO.
* Same size as `TBL` but updated with the best solution discovered.
* Stored back into the base workspace as `TBL` at the end of optimization.

### bestJ

* The minimal cost value found during the PSO run.
* Represents the best-so-far objective (`J`) over all particles and iterations.
* This is the metric the optimizer actually minimized.

### J\_final

* The cost value obtained by simulating the model *after applying `TBL_best`*.
* Confirms that the best LUT table indeed yields the expected cost when re-run in the model.
* May differ slightly from `bestJ` because `bestJ` is from evaluations inside PSO, while `J_final` is a fresh simulation.

### histJ

* History of the best-so-far cost per iteration.
* A vector where `histJ(it)` is the lowest `J` achieved up to iteration `it`.
* Used to generate the PSO convergence plot (iteration vs. best cost, often semilog y).
