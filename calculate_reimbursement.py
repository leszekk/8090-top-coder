import sys
import os
import numpy as np
import pandas as pd
import xgboost as xgb

# Set environment variables for consistent behavior
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["XGB_NUM_THREADS"] = "1"

# Set random seed
np.random.seed(42)

def create_features(X):
    X_new = X.copy()
    # Create some potentially useful features
    X_new['receipts_per_day'] = X['total_receipts_amount'] / np.maximum(X['trip_duration_days'], 1)
    X_new['miles_per_day'] = X['miles_traveled'] / np.maximum(X['trip_duration_days'], 1)
    X_new['receipts_per_mile'] = X['total_receipts_amount'] / np.maximum(X['miles_traveled'], 1)
    
    # Add trip duration categories
    X_new['short_trip'] = (X['trip_duration_days'] <= 3).astype(int)
    X_new['medium_trip'] = ((X['trip_duration_days'] > 3) & (X['trip_duration_days'] <= 7)).astype(int)
    X_new['long_trip'] = (X['trip_duration_days'] > 7).astype(int)
    
    # Add receipt amount categories
    X_new['low_receipts'] = (X['total_receipts_amount'] <= 500).astype(int)
    X_new['medium_receipts'] = ((X['total_receipts_amount'] > 500) & (X['total_receipts_amount'] <= 1500)).astype(int)
    X_new['high_receipts'] = (X['total_receipts_amount'] > 1500).astype(int)
    
    # Add mileage categories
    X_new['low_miles'] = (X['miles_traveled'] <= 300).astype(int)
    X_new['medium_miles'] = ((X['miles_traveled'] > 300) & (X['miles_traveled'] <= 800)).astype(int)
    X_new['high_miles'] = (X['miles_traveled'] > 800).astype(int)
    
    # Interaction features
    X_new['trip_miles_interaction'] = X['trip_duration_days'] * X['miles_traveled']
    X_new['trip_receipts_interaction'] = X['trip_duration_days'] * X['total_receipts_amount']
    X_new['miles_receipts_interaction'] = X['miles_traveled'] * X['total_receipts_amount']
    
    return X_new

def calculate_reimbursement(trip_duration_days, miles_traveled, total_receipts_amount):
    """
    Calculate reimbursement using a trained XGBoost model.
    """
    try:
        # Load the model with explicit deterministic settings
        model = xgb.XGBRegressor(n_jobs=1, tree_method='exact')
        model.load_model('reimbursement_model.json')
        
        # Create input features
        X = pd.DataFrame({
            'trip_duration_days': [trip_duration_days],
            'miles_traveled': [miles_traveled],
            'total_receipts_amount': [total_receipts_amount]
        })
        
        # Apply feature engineering
        X_featured = create_features(X)
        
        # Make prediction using the most deterministic approach
        dmatrix = xgb.DMatrix(X_featured)
        booster = model.get_booster()
        prediction = booster.predict(dmatrix)[0]
        
        # Round to exactly 2 decimal places
        return round(prediction * 100) / 100
    except Exception as e:
        # Fallback calculation if model fails
        print(f"Error: {e}", file=sys.stderr)
        base_per_diem = trip_duration_days * 95.0 if trip_duration_days != 4 else trip_duration_days * 85.0
        base_mileage = miles_traveled * 0.45
        base_receipt = min(500, total_receipts_amount) * 0.95
        if total_receipts_amount > 500:
            base_receipt += min(1000, total_receipts_amount - 500) * 0.75
        if total_receipts_amount > 1500:
            base_receipt += (total_receipts_amount - 1500) * 0.55
        return round(base_per_diem + base_mileage + base_receipt * 0.8, 2)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("0.0")
        sys.exit(0)

    try:
        duration = int(sys.argv[1])
        miles = float(sys.argv[2])
        receipts = float(sys.argv[3])
    except (ValueError, TypeError):
        print("0.0")
        sys.exit(0)

    result = calculate_reimbursement(duration, miles, receipts)
    print(result)
