# 8090-Inc Top Coder Response

This repository presents a machine learning-based approach for calculating travel reimbursements using trip duration, mileage, and receipt totals. The solution leverages XGBoost to model complex reimbursement patterns learned from historical data.

## Overview
Conventional rule-based reimbursement systems often fall short when handling the nuanced policies found in real-world scenarios. Attempts to reverse engineer such logic using GenAI lacked precision. This project replaces rigid conditional logic with a data-driven machine learning model capable of capturing subtle patterns and delivering accurate reimbursement estimates.


## Evaluation Status
✅ Evaluation Complete!

📈 Results Summary:
  Total test cases: 1000
  Successful runs: 1000
  Exact matches (±$0.01): 533 (53.3%)
  Close matches (±$1.00): 802 (80.2%)
  Average error: $34.63
  Maximum error: $701.45

  🎯 Your Score: 3509.70 (lower is better)
  🥉 Good progress! You understand some key patterns.


## Files
### Core Components
* `train_model.py`  – Trains the XGBoost model on provided data.
* `run.sh` – Bash script to execute the reimbursement calculation pipeline.
* `calculate_reimbursement.py` – Applies the trained model to compute reimbursements.
* `reimbursement_model.json` – Serialized XGBoost model (generated post-training).
* `private_results.txt` – Contains 5,000 model-generated reimbursement predictions.

### Supporting 
* `public_cases.json` – Dataset with 1,000 labeled examples used for model training.
* `private_cases.json` – Dataset with 5,000 test records for submission evaluation.
* `requirements.txt` – Lists necessary Python packages for running the code.
* `reimbursement_evaluation_20250607_224809.log` – Execution log with runtime stats and error metrics.

## [License](LICENSE.md) - MIT License
