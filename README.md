## ReconSAR

This repository contains public MATLAB scripts that demonstrate earthquake-related change detection workflow using **fully synthetic** data. All inputs are anonymized and generated over a small, Kathmandu-like area.

### Data files and Git LFS

| File in `data/` | How it is stored |
|-----------------|------------------|
| `synthetic_ps.mat`, `synthetic_grid_2500m.mat` | Normal Git (small) |
| **`buildings_2.mat`** | **Git LFS** (~157 MB). GitHub does not accept this file as a regular blob (100 MB limit); LFS stores the large binary separately. |

After **clone**, install [Git LFS](https://git-lfs.com/) once (`git lfs install`), then run **`git lfs pull`** in the repo so `data/buildings_2.mat` is downloaded. If that file is missing locally, building-based scripts will fail.

### Reference

The method implemented here follows the workflow described in:

**DOI:** [https://doi.org/10.1016/j.jag.2025.104883](https://doi.org/10.1016/j.jag.2025.104883)
*(International Journal of Applied Earth Observation and Geoinformation)*

### How this repository maps to the paper

Use the headings below as a **conceptual** map from the article’s methodology to this code.

| Part of the paper (method / idea) | What it is in this repo |
|-----------------------------------|-------------------------|
| **Study area, PS-like point clouds, and quality control** — pre- and post-event scatterer locations after masking and thresholds (e.g. coherence), used as inputs to spatial comparison | **`data/generate_synthetic_grid_points.m`** builds synthetic `pre` / `post` and `gridCells`, saved as `synthetic_ps.mat` and `synthetic_grid_2500m.mat`; the README’s “Data format” describes the same roles as the paper’s inputs (here without real SAR metadata; points stand in for filtered PS). |
| **Grid-based change detection** — counting pre- vs post-event points per cell and forming a difference (loss of scatterers per unit area) | **`src/change_detection_grid_public.m`** — counts points in each polygon, outputs `Nrpre`, `Nrpost`, `diff`; mirrors the paper’s grid workflow. |
| **Building-based change detection** — same comparison but aggregated inside each building footprint | **`src/change_detection_building_public.m`** — uses OSM-style footprints from `data/buildings_2.mat`, same count-and-difference logic at building scale. |
| **Grid density *D*<sub>grid</sub>** — normalized indicator at grid resolution | **`src/density_grid_public.m`** — CSV column `density` is *D*<sub>grid</sub> from the paper (same definition as in the article’s equations). Uses the grid change-detection CSV and a **synthetic** `numBuildings` per cell in this repo; for a real case study, use building counts per grid cell as in the paper. |
| **Building density *D*<sub>building</sub>** — normalized indicator per footprint | **`src/density_building_public.m`** — CSV column `density` is *D*<sub>building</sub> from the paper, using footprint **area** from `buildings_2.mat` and building-level `diff`. |
| **Numerical results / maps** — tabulated values per spatial unit for interpretation or mapping | **`results/*.csv`** — one row per grid cell or per building with IDs, centroids, counts, `diff`, and `density` (*D*<sub>grid</sub> or *D*<sub>building</sub> in the density outputs). |

The **`density`** column in `density_grid_synthetic.csv` is *D*<sub>grid</sub>; in `density_buildings_synthetic.csv` it is *D*<sub>building</sub> (paper notation; the scripts implement the same quantities as in the paper’s density definitions).

### Structure

- `data/`
  - `generate_synthetic_grid_points.m`: creates synthetic pre- and post-event point clouds (`pre`, `post`) and a grid of polygon cells (`gridCells`), and saves `synthetic_ps.mat` and `synthetic_grid_2500m.mat` in `data/` (see **How to run**).

- `src/`
  - `change_detection_grid_public.m`: performs grid-based change detection between `pre` and `post` by counting points per grid cell.
  - `change_detection_building_public.m`: performs building-based change detection between `pre` and `post` by counting points per building footprint.
  - `density_grid_public.m`: computes *D*<sub>grid</sub>; column `density` in the output CSV is *D*<sub>grid</sub> (synthetic `numBuildings` in this demo).
  - `density_building_public.m`: computes *D*<sub>building</sub>; column `density` in the output CSV is *D*<sub>building</sub> (uses footprint areas).
- `results/`
  - Output CSV files with change detection results are written here.

### Data format and logic

- Synthetic point clouds:
  - Stored in `data/synthetic_ps.mat` as:
    - `pre`  \[N x 3\] with columns \[ID, X, Y\]
    - `post` \[M x 3\] with columns \[ID, X, Y\]
  - Points are already filtered (you can treat them as having coherence ≥ 0.7); no additional coherence column is included.
- Grid-based workflow:
  - Uses either:
    - The predefined grid in `data/synthetic_grid_2500m.mat` (variable `gridCells` with `Lon`, `Lat`, `ID`), or
    - An auto-generated regular grid based on the extent of the synthetic points (if you switch that mode in the script).
  - Counts pre- and post-event points per cell, then computes `diff = Nrpre - Nrpost`.
- Building-based workflow:
  - Uses Kathmandu OSM building footprints from `data/buildings_2.mat` (struct array `buildings` with fields `X`, `Y`, `osm_id`).
  - Counts pre- and post-event points per building, then computes `diff = Nrpre - Nrpost`.

The same synthetic points are used for both the grid-based and building-based analyses; only the spatial aggregation (grid vs. buildings) changes.

### How to run

**Prerequisites**

- **MATLAB** with support for `polyshape`, `centroid`, `inpolygon`, and `readmatrix` (recent releases; `readmatrix` needs R2019a+).
- **Image Processing Toolbox** for `imgaussfilt` in the data generator only.
- **`data/buildings_2.mat`** is required for the building-based and building-density steps. It is not created by the generator; it is **versioned via Git LFS** (see **Data files and Git LFS** above). After clone, run `git lfs pull` if the file is missing. The grid-only pipeline does not need it.

**Workflow (run in this order)**

Keep **MATLAB’s current folder** as indicated so paths like `../data` and `../results` resolve correctly.

1. **Generate synthetic data**
   - In MATLAB, set the current folder to **`data`** (the folder that contains `generate_synthetic_grid_points.m`).
   - Run: `generate_synthetic_grid_points`
     (This calls the function defined in that file; it writes outputs into the current `data/` folder.)
   - Creates:
     - `data/synthetic_ps.mat` — **`pre` and `post` point sets** (synthetic points before / after the event). These are the data you count inside cells or buildings.
     - `data/synthetic_grid_2500m.mat` — **`gridCells`**, the **grid alone** (polygon boundaries and IDs for ~2500 m cells). It does not contain points; the grid script uses it to decide *where* to aggregate `pre`/`post`.

2. **Run grid-based change detection**
   - Set the current folder to **`src`**.
   - **Inputs** (read from `../data/` by the script):
     - `data/synthetic_ps.mat` — variables `pre`, `post`
     - `data/synthetic_grid_2500m.mat` — variable `gridCells` (cell polygons and IDs)
   - Open and run `change_detection_grid_public.m` (Editor **Run** or type the script name if it is on the path).
   - **Output:**
     - `results/change_detection_grid_synthetic_diff.csv`
   - Columns:
     - `ID`, `Xc`, `Yc`, `Nrpre`, `Nrpost`, `diff`

3. **Run building-based change detection**
   - Current folder still **`src`**.
   - **Inputs** (read from `../data/` by the script):
     - `data/synthetic_ps.mat` — variables `pre`, `post`
     - `data/buildings_2.mat` — variable `buildings` (footprint polygons and `osm_id`)
   - Open and run `change_detection_building_public.m`.
   - **Output:**
     - `results/change_detection_buildings_synthetic_diff.csv`
   - Columns:
     - `ID`, `Xc`, `Yc`, `Nrpre`, `Nrpost`, `diff`

4. **Run density analyses (*D*<sub>grid</sub> and *D*<sub>building</sub>)**
   - Current folder still **`src`**.
   - **`density_grid_public.m`** — column `density` is *D*<sub>grid</sub> (paper).
   - **Inputs** (script reads `../results/`; paths below are relative to repo root):
     - `results/change_detection_grid_synthetic_diff.csv` — output of step 2 (`ID`, `Xc`, `Yc`, `Nrpre`, `Nrpost`, `diff`)
     - **`numBuildings` is not a file** here: the script generates a **synthetic** count per grid cell for this demo (for a real study, replace that logic with your vector of building counts per cell, as in the paper).
   - **Output:**
     - `results/density_grid_synthetic.csv`
     - Columns: `ID`, `Xc`, `Yc`, `Nrpre`, `Nrpost`, `diff`, `numBuildings`, `density` (= *D*<sub>grid</sub>).
   - **`density_building_public.m`** — column `density` is *D*<sub>building</sub> (paper).
   - **Inputs** (read from `../results/` and `../data/`):
     - `results/change_detection_buildings_synthetic_diff.csv` — output of step 3
     - `data/buildings_2.mat` — variable `buildings` (footprints used to compute **area** per row)
   - **Output:**
     - `results/density_buildings_synthetic.csv`
   - Columns: `ID`, `Xc`, `Yc`, `Nrpre`, `Nrpost`, `diff`, `area`, `density` (= *D*<sub>building</sub>).

### Funding

P.M. (one of the contributors to this project) was funded by the **National Aeronautics and Space Administration (NASA)** under a contract with the **Commercial Smallsat Data Scientific Analysis Program** (**NNH22ZDA001N-CSDSA**), and the **Decadal Survey Incubation Program: Science and Technology** (**NNH21ZDA001N-DSI**).

### Notes

- All inputs (EXCEPT OSM building footprints) are **synthetic** and do not contain any proprietary or real earthquake data.
- Random number generator seeds are fixed so that anyone cloning the repo can reproduce the same synthetic example.


