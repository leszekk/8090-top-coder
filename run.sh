#!/bin/bash
# Black Box Challenge - Krzysztof Leszek
# This script should take three parameters and output the reimbursement amount
# Usage: ./run.sh <trip_duration_days> <miles_traveled> <total_receipts_amount>

# Calls the Python script that contains the core calculation logic
python calculate_reimbursement.py "$1" "$2" "$3"