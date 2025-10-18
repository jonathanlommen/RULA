# Repository Guidelines

## Project Structure & Module Organization
`RULA_based_on_IMU_START.m` orchestrates the full ergonomic workflow from the repository root; open it first when extending the pipeline. Unpack `skripts.zip` beside the entry script so MATLAB can reach `skripts/MF_*.m` helpers and the bundled `skripts/spm1dmatlab-master/` library. Extract the three data archives into a single `data/` folder so the script can resolve MVNX-derived `.mat` files through `PathNameMAT = [pwd '\data']`. Keep `Surgeon_db.xlsx` in the root; its `Stammdaten`, `Condition`, and `Filedb` sheets drive subject metadata and scoring lookups.
`RULA_Visualizer.m` provides a post-processing GUI for exploring joint-angle time series and summary scores after running `run_all_trials`.

## Build, Test, and Development Commands
Run the end-to-end pipeline from a MATLAB shell with `matlab -batch "run('RULA_based_on_IMU_START.m')"`; the script adds the `skripts/` folder to the path, ingests raw data, and exports `Results.xlsx`. While iterating, use `addpath(fullfile(pwd,'skripts'))` once per session, then call individual modules such as `MF_02SelectAndRULA` to isolate stages. Regenerate histograms by invoking `MF_combine_RULA_hist` after a data change; it expects the same `Data` and `ConditionTable_loaded` structures emitted by the main run.

## Coding Style & Naming Conventions
Follow the existing MATLAB style: four-space indentation, lowercase keywords, and descriptive mixed-case identifiers (`ConditionTable.SubjectID`, `Subject_db`). Prefix new pipeline functions with `MF_` to keep navigation consistent, and place derived tables in structures with explicit fields instead of numeric indices. Document any workflow-specific decisions with brief English comments directly above the affected block.

## Testing Guidelines
There is no automated test suite; rely on deterministic reruns. After modifying a function, rerun `RULA_based_on_IMU_START` on a representative subset and confirm the regenerated `Results.xlsx` matches expected totals. For statistical changes, re-execute `MF_combine_RULA_hist` and review the plotted distributions against prior exports. Save intermediate structures with `save('debug.mat','Data','ConditionTable_loaded')` when comparing outputs across branches.

## Commit & Pull Request Guidelines
Keep commits focused and use concise subject lines in the style of the existing history (`Add files via upload`); prefer imperative phrasing like `Refine RULA scoring thresholds`. Reference related issues or datasets in the body and list any required MATLAB version or toolbox notes. Pull requests should include a short scenario summary, reproduction steps (`matlab -batch "run('RULA_based_on_IMU_START.m')"`), regenerated artifacts (attach `Results.xlsx` diffs), and call out any new dependencies the reviewer must install.

## Data & Configuration Notes
Protect raw MVNX files by working in `01_rawData/` and letting the scripts copy them into `01_rawDataconverted/`. Update `Surgeon_db.xlsx` first when onboarding new subjects; the conversion stage cross-checks filenames against `Filedb.Filename`. Archive generated `Results.xlsx` and histograms outside the repository before committing to keep the repo lightweight.
