# RULA IMU Processing

This project processes wearable motion capture recordings to compute Rapid Upper Limb Assessment (RULA) scores for ergonomics research. XSens `.mvnx` trials are converted into MATLAB structures, posture scores are calculated per frame, and summary statistics plus histograms are generated for each participant and condition.

## Repository Layout
- `RULA_based_on_IMU_START.m` – legacy entry point that orchestrates the full MATLAB workflow.
- `run_all_trials.m` – automation script that converts all `.mvnx` trials in `01_rawData/` and runs the full RULA pipeline non-interactively.
- `skripts.zip` – MATLAB helper functions (unzip to `skripts/`) including:
  - `MF_01Conditiontable.m` / `MF_02SelectAndRULA.m` – build trial metadata, load converted data, and invoke scoring.
  - `MF_readMVNX.m` – parses XSens MVNX XML into MATLAB structs.
  - `RULA_calc_scores.m` / `RULA_calc_scores_rel.m` – core RULA scoring logic.
  - `MF_combine_RULA.m` / `MF_combine_RULA_hist.m` – summarise results and produce histograms.
- `RULA_tables/` – Excel lookup tables (Table A/B/C) used during scoring.

## Required Inputs
1. XSens MVNX recordings placed in `01_rawData/`.
2. RULA lookup spreadsheets (`Wrist and Arm Posture Score.xlsx`, `Trunk Posture Score.xlsx`, `Table C.xlsx`) inside `RULA_tables/`.
3. Optional: `Surgeon_db.xlsx` for detailed participant metadata. The automation script can fabricate minimal placeholders if the workbook is absent.

## Running the Pipeline
```matlab
run_all_trials
```
The script:
1. Ensures `skripts/` and `RULA_tables/` exist (extracting from the bundled ZIP archives if necessary) and adds them to the MATLAB path.
2. Converts each `.mvnx` file in `01_rawData/` into a `.mat` file in `data/` using `MF_readMVNX`.
3. Builds a temporary `ConditionTable` and `Subject_db` and runs `MF_02SelectAndRULA`, which loads every trial, filters the data, and calls the RULA routines.
4. Saves per-trial caches under `04_Processed/`, aggregates statistics with `MF_combine_RULA`, and writes the summary to `Results.xlsx`.
5. Stores the captured `Settings` struct in `Project_settings.mat` for reproducibility.

To explore the processed data interactively, either pass the `launchVisualizer` flag when running the batch script:

```matlab
run_all_trials('launchVisualizer', true)
```

or call `RULA_Visualizer` afterwards to open the GUI.

To execute the older interactive workflow, run `RULA_based_on_IMU_START.m` from MATLAB and follow the prompts.

## How RULA Scores Are Computed
1. **Data Preparation** – `MF_readMVNX` reads orientation, position, joint angles, and centre of mass values for each frame. `MF_02SelectAndRULA` filters the dataset to the configured conditions, computes derivatives (e.g., joint-angle velocity), and prepares structures consumed by the scoring routines.
2. **Posture Scoring** – `RULA_calc_scores` evaluates each joint/segment per frame against the official RULA tables:
   - Step 1–4: Upper arm, lower arm, and wrist posture scores for left/right limbs.
   - Step 5–9: Resting muscle use, force/load, neck, and trunk posture adjustments.
   - Step 10–15: Combination tables (Table A/B/C) yield final group and overall scores.
3. **Relative Frequencies** – `RULA_calc_scores_rel` captures how often each score occurs, generating relative histograms used later for reporting.
4. **Aggregation & Visualisation** – `MF_combine_RULA` computes medians and quartiles for every step and limb across frames and trials, while `MF_combine_RULA_hist` produces smoothed histograms and runs non-parametric comparisons.

The per-trial results (`*_processed.mat`) include the full `rula` struct, allowing deeper analysis such as frame-by-frame score inspection or custom visualisation.

## Outputs
- `Results.xlsx` – Summary table listing subject/condition metadata, overall scores, and quartiles for every RULA step.
- `04_Processed/` – Per-trial MAT files containing raw data subsets, computed scores, and parameters.
- Optional figures – When `MF_combine_RULA_hist` runs, MATLAB figures are created to compare score distributions between groups (e.g., operator vs assistant).

## Next Steps
- Extend `run_all_trials.m` to export frame-level scores if needed for time-series analysis.
- Update `Surgeon_db.xlsx` with participant metadata prior to a run to retain rich context in the output tables.
- Use `RULA_Visualizer` to inspect joint-angle time series (with RULA thresholds) and overall score distributions for any processed trial.
- Version-control new helper scripts by editing files under `skripts/` and updating `skripts.zip`.
