# 8090-Inc Top Coder Response

This repository contains a machine learning solution for calculating travel reimbursements based on trip duration, miles traveled, and receipt amounts. The solution uses XGBoost to learn complex patterns in reimbursement calculations from historical data.

## Overview
Traditional rule-based reimbursement calculators often struggle with the complexity of real-world reimbursement policies. Reverse engineering via GenAI struggled with accuracy. This project replaces complex conditional logic with a machine learning model that can capture intricate patterns and produce accurate reimbursement amounts.


## Files
* train_model.py - Script to train the XGBoost model
* run.sh - bash script to trigger reimbursement calculation 
* calculate_reimbursement.py -  Script that calculates reimbursements using the trained model
* reimbursement_model.json - The trained model file (generated after training)
* public_cases.json - Dataset with 1000 examples used for model training
* private_cases.json - Dataset with 5000 submissions
* requirements.txt - python dependencies that the code needs to run properly
* reimbursement_evaluation_20250607_224809.log - reimbursement calculation log with execution time and error rate

## [License](LICENSE.md) - MIT
