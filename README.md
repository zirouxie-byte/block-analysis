# Block Analysis

MATLAB application for measuring the elastic modulus of hydrogel samples 
using digital image correlation and Bayesian calibration.

## What it does

A six-step interactive pipeline:

1. **Spring calibration** — Bayesian MCMC fit of force vs. displacement
2. **Pixel calibration** — pixels-per-millimeter from reference block clicks
3. **ROI selection** — pick 4 patches on a reference image
4. **DIC tracking** — track patches across an image series
5. **Unit conversion** — convert pixel distances to mm and grams
6. **MLE fit** — maximum likelihood fit of stress vs. strain → elastic modulus

## How to run

### From MATLAB source

Clone or download this repo. Open MATLAB (R2024a or later recommended) and 
navigate to the project folder. In the Command Window:

```matlab
BlockAnalysisApp
```

Requires the Statistics and Machine Learning Toolbox and Image Processing Toolbox.

### As a standalone Windows installer

A precompiled installer (~2.8 MB) that runs without MATLAB is available on 
request — contact [your email]. The installer downloads the MATLAB Runtime 
(~2 GB) on first install.

## Usage

Open the **Instructions** tab inside the app for a complete step-by-step guide.

## Files

- `BlockAnalysisApp.m` — main app
- `load_px2dist_data_app.m` — interactive corner-click helper
- `main.m`, `calibration_spring.m`, `DIC_distance_calculation.m`, etc. — 
  pipeline modules

## Author

Zirou [last name] — University of Michigan
