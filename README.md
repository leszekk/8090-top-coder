# 8090-Inc Top Coder Response

This repository presents a machine learning-based approach for calculating travel reimbursements using trip duration, mileage, and receipt totals. The solution leverages XGBoost to model complex reimbursement patterns learned from historical data.

## Overview
Conventional rule-based reimbursement systems often fall short when handling the nuanced policies found in real-world scenarios. Attempts to reverse engineer such logic using GenAI lacked precision. This project replaces rigid conditional logic with a data-driven machine learning model capable of capturing subtle patterns and delivering accurate reimbursement estimates.


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
