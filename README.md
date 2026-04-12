# Sleep Apnea ECG Hardware Pipeline

This repository contains a Verilog implementation of an FPGA-oriented sleep apnea detection pipeline for ECG signals. The design processes a stream of 16-bit ECG samples, extracts signal features in hardware, and feeds those features into a neural-network classifier to generate a prediction.

At a high level, the pipeline is:

`ECG input -> filtering -> wavelet decomposition -> feature extraction -> feature synchronization -> neural network -> prediction`

This README is written for a new reader who wants to understand the codebase module by module.

## What This Codebase Is Trying To Do

The goal of the project is to detect sleep apnea from ECG data using a hardware-friendly signal-processing and machine-learning pipeline.

The overall idea is:

1. Accept ECG samples as signed 16-bit input data.
2. Remove noise and baseline effects with an IIR filter.
3. Split the filtered signal into multiple wavelet subbands.
4. Compute handcrafted features from those subbands.
5. Build a 15-feature vector.
6. Run a neural network on that feature vector.
7. Output a classification result.

This is not a general software ML project. It is a hardware datapath written in Verilog, intended for FPGA-style implementation.

## Main Files In The Repository

- `sleep_apnea_top.v`: top-level integration of the complete pipeline
- `myiir.v`: ECG preprocessing filter
- `lwt.v`: 3-level lifting wavelet transform
- `absolutemean.v`: generic absolute-mean engine plus level-1 wrapper
- `absmean2.v`: level-2 absolute-mean wrapper
- `absmean3.v`: level-3 absolute-mean wrapper
- `kurt.v`: generic kurtosis engine plus level-1 wrapper
- `kurt_two.v`: kurtosis wrapper for one of the level-3 detail bands
- `kurtaprx.v`: kurtosis wrapper for the approximation band
- `aadnle.v`: generic average-absolute-difference / nonlinear-energy engine plus level-1 wrapper
- `aadnle3.v`: level-3 detail-band AAD/NLE wrapper
- `aadnle_a3.v`: approximation-band AAD/NLE wrapper
- `hjorth.v`: compatibility wrapper around the generic AAD/NLE engine
- `mfactor.v`: complex variance / mobility / irregularity style feature engine
- `mobthr.v`: level-3 mobility / irregularity engine
- `moba3.v`: approximation-band mobility-like wrapper
- `neuralnet.v`: neural-network inference engine

## System-Level Dataflow

The intended top-level dataflow is visible in `sleep_apnea_top.v`.

### Inputs

- `clk`: system clock
- `rst`: reset
- `valid_in`: indicates when `ecg_data_in` is valid
- `ecg_data_in`: signed 16-bit ECG sample input

### Outputs

- `classification_out`: final classifier output (signed 50-bit)
- `prediction_valid`: pulses when the prediction result is ready

### Pipeline Stages

1. ECG data enters the preprocessing filter.
2. The filtered result enters the wavelet transform.
3. The wavelet block produces detail and approximation subbands.
4. Feature extractors consume those subbands over fixed windows.
5. Once the required features are ready, the neural network is triggered.
6. The network accumulates its final score and raises `prediction_valid`.

## Top-Level Integration: `sleep_apnea_top.v`

This is the file a new reader should start with, because it shows the intended architecture of the whole project.

### What It Instantiates

- `myiir`: preprocessing filter
- `lwtbior`: wavelet decomposition
- feature extractors for `CD1`, `CD2`, `CD3`, and `CA3`
- `neuralnet_top`: final classifier

### Intended Wavelet Outputs Used By The Top Level

- `CD1`: detail coefficients from level 1
- `CD2`: detail coefficients from level 2
- `CD3`: detail coefficients from level 3
- `CA3`: approximation coefficients from level 3

### Intended Feature Vector Sent To The Neural Network

The top-level file maps 15 features into the neural net:

- `f1`: mean of `CD1`
- `f2`: variance-like feature from `CD1`
- `f3`: kurtosis of `CD1`
- `f4`: mobility-like feature from `CD1`
- `f5`: kurtosis of `CD3`
- `f6`: kurtosis of `CA3`
- `f7`: mean of `CD2`
- `f8`: mean of `CD3`
- `f9`: mobility-like feature from `CA3`
- `f10`: nonlinear energy from `CD1`
- `f11`: nonlinear energy from `CA3`
- `f12`: nonlinear energy from `CD3`
- `f13`: irregularity from `CD3`
- `f14`: average absolute deviation from `CD3`
- `f15`: mobility from `CD3`

### Important Note

The top-level file clearly shows the intended architecture, but some lower-level module interfaces do not currently match it exactly. So it is best to treat `sleep_apnea_top.v` as the architectural blueprint, even if some port names still need cleanup.

## Module-By-Module Explanation

## 1. `myiir.v`

This file implements ECG preprocessing.

### Module: `myiir`

Purpose:
Apply a two-stage biquad IIR filter to the incoming ECG stream.

How it works:
- Instantiates two second-order sections (`Biquad_SOS`) in cascade.
- The output of stage 1 is registered and sent to stage 2.
- The output of stage 2 becomes the filtered ECG output.

Why this matters:
Feature extraction is sensitive to noise, baseline drift, and waveform distortion. This filter is intended to clean the ECG signal before wavelet decomposition.

### Module: `Biquad_SOS`

Purpose:
Implement one second-order IIR section using fixed-point arithmetic.

Internal behavior:
- Stores delayed input samples in `x1`, `x2`
- Stores delayed output samples in `y1`, `y2`
- Computes feedforward terms from current and previous inputs
- Computes feedback terms from previous outputs
- Applies right-shift scaling to reduce arithmetic cost
- Saturates the final result to signed 16-bit

Why it is written this way:
- FPGA designs usually avoid floating-point if possible
- shift-based scaling is cheaper than division
- saturation protects against overflow in intermediate sums

## 2. `lwt.v`

This file implements the multi-level wavelet decomposition stage.

### Module: `lwtbior`

Purpose:
Perform a 3-level lifting wavelet transform and expose the detail and approximation outputs.

How it is organized:
- `stage1` processes the filtered ECG input
- `stage2` processes the approximation output of stage 1
- `stage3` processes the approximation output of stage 2

Outputs of interest:
- `det1_nrm`: normalized detail at level 1
- `det2_nrm`: normalized detail at level 2
- `det3_nrm`: normalized detail at level 3
- `aprx3_nrm`: normalized approximation at level 3
- `valid_L1`, `valid_L2`, `valid_L3`: band-valid signals

Why there are many extra outputs:
Some raw and intermediate ports are preserved for compatibility with older versions of the design or for debugging.

### Module: `lwt_stage`

Purpose:
Implement one lifting-based wavelet stage.

Internal behavior:
- Alternates between even and odd samples
- Stores recent samples needed for lifting operations
- Computes detail using a predict step
- Computes approximation using an update step
- Produces normalized outputs
- Delays `valid_out` until startup transients are gone

Why it matters:
This block converts the ECG into multiple time-frequency bands. The rest of the feature extraction code depends on these bands.

## 3. `absolutemean.v`

This file contains the generic absolute-mean feature engine and the level-1 wrapper.

### Module: `feature_absmean`

Purpose:
Compute the mean absolute value of a signal over a frame.

Internal behavior:
- Converts the signed input into its magnitude
- Accumulates magnitudes in `acc`
- Counts samples using `sample_cnt`
- When the frame ends, applies shift-based scaling to approximate division
- Outputs the feature value as `mean_out`
- Pulses `valid_out` when the result is ready

Why this feature exists:
Mean absolute value is a simple amplitude/energy-related statistic and is often used in physiological signal analysis.

### Module: `absolutemean`

Purpose:
Wrap `feature_absmean` for the level-1 detail band.

Configuration:
- `LEVEL = 1`
- `FRAME_SIZE = 3002`

This is intended for `CD1`.

## 4. `absmean2.v`

### Module: `absmean2`

Purpose:
Wrap `feature_absmean` for the level-2 detail band.

Configuration:
- `LEVEL = 2`
- `FRAME_SIZE = 1500`

This is intended for `CD2`.

## 5. `absmean3.v`

### Module: `absmean3`

Purpose:
Wrap `feature_absmean` for the level-3 detail band.

Configuration:
- `LEVEL = 3`
- `FRAME_SIZE = 750`

This is intended for `CD3`.

## 6. `kurt.v`

This file contains the generic kurtosis engine and the level-1 wrapper.

### Module: `feature_kurtosis`

Purpose:
Compute a kurtosis-like feature over a frame.

Internal behavior:
- Squares the input sample
- Squares again to generate a fourth-order term
- Accumulates both second-order and fourth-order terms over the full frame
- Applies scaling shifts
- Multiplies by an `N_MULT` constant
- Uses a custom iterative divider to compute the final ratio
- Pulses `startk` when the result is valid

Why it is more complex:
Kurtosis uses fourth-order statistics, so internal values grow large quickly. That makes the datapath wider and the implementation more involved than simpler features.

### Module: `kurt_division`

Purpose:
Provide an iterative shift-subtract divider used by the kurtosis engine.

Why it exists:
General division is expensive in hardware. This block lets the kurtosis engine trigger a multi-cycle division and wait for `result_valid`.

### Module: `kurt`

Purpose:
Level-1 wrapper for kurtosis.

Configuration:
- `FRAME_SIZE = 3002`
- `N_MULT = 3000`
- `SHIFT_VAL = 19`

Used for `CD1`.

## 7. `kurt_two.v`

### Module: `kurt_two`

Purpose:
Wrapper for a level-3 detail-band kurtosis feature.

Configuration:
- `FRAME_SIZE = 750`
- `N_MULT = 750`
- `SHIFT_VAL = 29`

In the current top-level integration, this is used for `CD3`.

## 8. `kurtaprx.v`

### Module: `kurtaprx`

Purpose:
Wrapper for approximation-band kurtosis.

Configuration:
- `FRAME_SIZE = 750`
- `N_MULT = 750`
- `SHIFT_VAL = 29`

In the current top-level integration, this is used for `CA3`.

## 9. `aadnle.v`

This file contains a reusable engine that computes average-absolute-difference style and nonlinear-energy style features.

### Module: `feature_aad_nle`

Purpose:
Compute two features over a frame:
- an AAD-like feature
- a nonlinear-energy feature

Internal behavior:
- Truncates the input to a narrower internal width
- Maintains a delay line of recent samples
- Computes `diff_aad = x[n] - x[n-1]`
- Takes the absolute value of that difference for the AAD path
- Computes a nonlinear-energy style term using `x[n]^2 - x[n] * x[n-k]`
- Accumulates both results over the full frame
- Applies shift-based output scaling
- Pulses `start_pulse` when the outputs are ready

Why it is important:
This is one of the most reused cores in the repo. Several wrappers simply configure it for different wavelet bands and frame sizes.

### Module: `aadnle`

Purpose:
Level-1 wrapper around `feature_aad_nle`.

Configuration:
- `LEVEL = 1`
- `FRAME_SIZE = 3002`
- `TEO_DELAY_TAPS = 3`

Used for `CD1`.

## 10. `aadnle3.v`

### Module: `aadnle3`

Purpose:
Level-3 detail-band wrapper for AAD and nonlinear energy.

Configuration:
- `LEVEL = 3`
- `FRAME_SIZE = 750`
- `TEO_DELAY_TAPS = 10`

Outputs:
- `aad33`
- `nle3`

Used for `CD3`.

## 11. `aadnle_a3.v`

### Module: `aadnle_a3`

Purpose:
Approximation-band wrapper for AAD and nonlinear energy.

Configuration:
- `LEVEL = 3`
- `FRAME_SIZE = 750`
- `TEO_DELAY_TAPS = 10`

In the current top-level design, the nonlinear-energy output is the one mainly consumed.

## 12. `hjorth.v`

### Module: `hjorth`

Purpose:
Provide a compatibility wrapper around `feature_aad_nle` using Hjorth-related names.

Behavior:
- Reuses the generic engine from `aadnle.v`
- Renames outputs to match older naming conventions
- Adds extra compatibility trigger outputs (`startbram2`, `startac`), which are aliases of the main done signal
- Acts more like an adapter than a separate algorithm

Why it exists:
It preserves compatibility with an earlier code structure or older top-level expectations.

## 13. `mfactor.v`

This file contains one of the most complex feature-extraction paths in the project.

### Module: `mfactor`

Purpose:
Compute variance-like, mobility-like, and irregularity-related quantities from the level-1 detail band.

Internal behavior:
- Forms first and second differences
- Accumulates energy/statistical terms over a frame (hardcoded to 3000 samples, not parameterized)
- Applies scaling shifts after frame completion
- Starts a division stage
- Starts square-root stages
- Starts a second division stage
- Pulses `start_mob` when the final values are ready

Why this block is complex:
Unlike the simpler feature blocks, this one performs several dependent stages of math after the accumulation window ends. It is effectively a small pipeline controller plus arithmetic engine. Note that the frame count is hardcoded rather than parameterized like other feature blocks.

Supporting modules in this file:
- `sroot_mf`: iterative square root
- `division_mf`: iterative division
- `project_ad12_m`: helper adder
- `multiplier123_m`, `multiplier1234_m`: helper multipliers

## 14. `mobthr.v`

This file is structurally similar to `mfactor.v`, but tuned for the level-3 detail band.

### Module: `mobthr`

Purpose:
Compute mobility and irregularity style features from `CD3`.

Internal behavior:
- Builds first and second differences
- Accumulates frame-level statistics (hardcoded to 750 samples, not parameterized)
- Applies scaling
- Launches iterative division
- Launches square-root stages
- Launches a second division
- Pulses `start` when outputs are valid

Supporting modules in this file:
- `sroot_thr`: iterative square root
- `division_thr`: iterative division
- `project_ad12_thr`: helper adder
- `multiplier123_thr`, `multiplier1234_thr`: helper multipliers

Why it matters:
This block contributes some of the more advanced `CD3` features used by the classifier.

## 15. `moba3.v`

### Module: `moba3`

Purpose:
Generate a mobility-like approximation from the approximation band `CA3`.

How it works:
- Reuses the generic `feature_aad_nle` engine
- Uses the nonlinear-energy-style output as a compact proxy mobility feature

This is a lightweight wrapper rather than a large standalone implementation.

## 16. `neuralnet.v`

This file contains the classifier and all of the supporting arithmetic blocks it uses.

### Module: `neuralnet_top`

Purpose:
Consume 15 extracted features and generate the final classification output.

Network structure:
- 15 inputs
- 100 hidden neurons
- 1 output accumulation path

How it works:
1. `start_prediction` begins a neural-network inference.
2. `rom_addr` steps from 0 to 99.
3. For each hidden neuron index:
- input weights are fetched from ROM
- one hidden-layer bias is fetched
- one output-layer weight is fetched
4. The 15 input features are multiplied by the 15 hidden weights.
5. An adder tree sums the products.
6. The bias is added.
7. ReLU is applied.
8. The hidden activation is multiplied by the output weight.
9. That contribution is added into the final accumulator.
10. When the pipeline flushes, `done` pulses and `classification_out` is finalized.

Why it is implemented this way:
A fully parallel 15x100 hidden layer would consume significantly more hardware resources. This design reuses arithmetic over many cycles to save area.

### Module: `weight_rom`

Purpose:
Store one set of 100 signed 16-bit weights using `$readmemh`.

Expected external files:
- `weight1.data` through `weight15.data`
- `outputwt.data`

### Module: `bias_rom`

Purpose:
Store hidden-layer biases.

Important current behavior:
The memory is first initialized to zero and then loaded from a hex file via `$readmemh`. The top-level passes `"bias_hidden.data"` as the init file. If the file is missing, the biases remain zero.

### Other Neural-Network Helper Modules

- `mult_wt_nn`: input-weight multiplier
- `mult_wt1_nn`: hidden-output multiplier
- `adder_tree_nn`: sums the 15 weighted inputs
- `relu_nn`: applies ReLU activation

## Frame Sizes And Timing Model

One important thing for a new reader is that this repo mixes streaming behavior and frame-based feature generation.

### Streaming Front End

- ECG samples move one sample at a time through the filter and wavelet blocks.
- Some blocks use `valid_in` and `valid_out` to indicate when outputs are meaningful.

### Frame-Based Feature Extraction

Most feature engines do not emit one feature per sample. Instead, they:
- accumulate statistics over a fixed number of samples
- complete their math
- pulse a done/valid signal when the feature value is ready

Typical frame sizes in the code:
- `3002` samples for level-1 parameterized features (`absolutemean`, `kurt`, `aadnle`), or `3000` hardcoded in `mfactor`
- `1500` samples for level-2 features
- `750` samples for level-3 features

### What That Means Practically

This design behaves more like:

- collect a frame
- compute features for that frame
- run one inference for that frame

It is not a per-sample classifier.

## Reading Strategy For A New Developer

A good reading order is:

1. `sleep_apnea_top.v`
2. `myiir.v`
3. `lwt.v`
4. `absolutemean.v`
5. `aadnle.v`
6. `kurt.v`
7. `mfactor.v`
8. `mobthr.v`
9. `neuralnet.v`
10. then the small wrapper modules

That order helps because:
- first you understand the architecture
- then the front-end DSP
- then the reusable feature cores
- then the more complex feature engines
- then the neural network

## Known Codebase Reality Check

A new reader should know this upfront:

- The top-level module clearly expresses the intended architecture.
- Some lower-level wrappers still use inconsistent port names.
- Some modules look like they were refactored toward valid-driven streaming, while others still behave like fixed-window legacy engines.
- The neural network expects external `.data` files for weights.
- Some arithmetic is approximate fixed-point logic using shifts rather than exact division.

## Summary

This repository implements a hardware ECG analysis pipeline for sleep apnea detection.

It combines:
- fixed-point filtering
- wavelet decomposition
- handcrafted biomedical signal features
- a resource-aware neural-network inference engine

The key mental model is simple:

`filtered ECG -> wavelet bands -> handcrafted features -> 15-feature vector -> neural network -> prediction`
