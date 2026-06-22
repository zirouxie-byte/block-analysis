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

## Downloads

- **[Standalone Windows installer](https://drive.google.com/file/d/1pLaL4crCfhYHoUI5Aj9y0DZfCUjG2zGD/view?usp=sharing)** (2.8 MB) — runs without MATLAB. Downloads the MATLAB Runtime (~2 GB) on first install.
- **[Deployment log](https://drive.google.com/file/d/13nuuobNNXn308JsZfUM3rgRwn5kWIYHU/view?usp=sharing)** — build report from the MATLAB compilation.

When running the installer, Windows may show a "Windows protected your PC" warning. Click **More info** → **Run anyway**. This is normal for unsigned academic software.

## How to run

### From MATLAB source

Clone or download this repo. Open MATLAB (R2024a or later recommended) and 
navigate to the project folder. In the Command Window:

​```matlab
BlockAnalysisApp
​```

Requires the Statistics and Machine Learning Toolbox and Image Processing Toolbox.

### As a standalone Windows installer

Download the installer from the link above. Run it (clicking past the Windows 
protection warning if needed), and the MATLAB Runtime will download automatically 
on first install. After installation, find "Block Analysis" in your Start Menu.

For an offline copy or for collaborators outside UMich, contact zirouxie@umich.edu.

## Usage

Open the **Instructions** tab inside the app for a complete step-by-step guide.

## Files

- `BlockAnalysisApp.m` — main app
- `load_px2dist_data_app.m` — interactive corner-click helper
- `main.m`, `calibration_spring.m`, `DIC_distance_calculation.m`, etc. — 
  pipeline modules

## Authors

Lauren Abbruzzese, Likhitha Sree Galam, Meghana Kasturi, Caymen Novak, Jesus Pereira Pires, Rafael Ruiz, Rebecca Schmidt, Zirou Xie — The University of Michigan-Dearborn
