import xgboost as xgb
import pandas as pd
import numpy as np
import json
import os
import random
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error

# Set all seeds for reproducibility
def set_all_seeds(seed=42):
    np.random.seed(seed)
    random.seed(seed)
    os.environ['PYTHONHASHSEED'] = str(seed)
    
set_all_seeds(42)

print(f"Using XGBoost version: {xgb.__version__}")

# Load all training data
print("Loading public_cases.json...")
try:
    with open('public_cases.json', 'r') as f:
        data = json.load(f)
    
    # Extract all examples
    examples = []
    for item in data:
        try:
            # Handle potential variations in the JSON structure
            if 'input' in item and 'expected_output' in item:
                input_data = item['input']
                
                # Handle the trip_duration_days typo if it exists
                trip_days = input_data.get('trip_duration_days', input_data.get('trip_duraDon_days'))
                
                examples.append({
                    'trip_duration_days': trip_days,
                    'miles_traveled': input_data['miles_traveled'],
                    'total_receipts_amount': input_data['total_receipts_amount'],
                    'expected_output': item['expected_output']
                })
        except Exception as e:
            print(f"Error processing example: {e}")
            continue
    
    # Convert to DataFrame and sort to ensure consistent ordering
    df = pd.DataFrame(examples)
    df = df.sort_values(by=['trip_duration_days', 'miles_traveled', 'total_receipts_amount']).reset_index(drop=True)
    
    print(f"Loaded {len(df)} training examples")
    
except Exception as e:
    print(f"Error loading data: {e}")
    exit()

# Create feature matrix and target vector
X = df[['trip_duration_days', 'miles_traveled', 'total_receipts_amount']]
y = df['expected_output']

# Use fixed indices for train/test split instead of random
indices = np.arange(len(X))
train_indices = indices[:int(0.8 * len(indices))]
val_indices = indices[int(0.8 * len(indices)):]

X_train, X_val = X.iloc[train_indices], X.iloc[val_indices]
y_train, y_val = y.iloc[train_indices], y.iloc[val_indices]

print(f"Training on {len(X_train)} examples, validating on {len(X_val)} examples")

# Create feature engineering
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

X_train_featured = create_features(X_train)
X_val_featured = create_features(X_val)

# Train XGBoost model with deterministic settings
print("Training XGBoost model...")
model = xgb.XGBRegressor(
    objective='reg:squarederror',
    n_estimators=50000,          # Reduced from 50000 for consistency
    max_depth=8,
    learning_rate=0.03,
    subsample=0.8,
    colsample_bytree=0.8,
    reg_alpha=0.1,
    reg_lambda=1.0,
    random_state=42,
    n_jobs=1,                   # Single thread for reproducibility
    tree_method='exact'         # Use exact split finding
)

# Simple fit without problematic parameters
print("Fitting model...")
model.fit(X_train_featured, y_train)
print("Model training complete")

# Evaluate model
y_pred_train = model.predict(X_train_featured)
mae_train = mean_absolute_error(y_train, y_pred_train)
print(f"Training Mean Absolute Error: ${mae_train:.2f}")

y_pred = model.predict(X_val_featured)
mae = mean_absolute_error(y_val, y_pred)
print(f"Validation Mean Absolute Error: ${mae:.2f}")

# Calculate percentage of predictions within $0.01 and $1.00
exact_matches = np.sum(np.abs(y_val - y_pred) <= 0.01)
close_matches = np.sum(np.abs(y_val - y_pred) <= 1.00)
print(f"Exact matches (±$0.01): {exact_matches} ({exact_matches/len(y_val)*100:.2f}%)")
print(f"Close matches (±$1.00): {close_matches} ({close_matches/len(y_val)*100:.2f}%)")

# Show feature importance
importance = model.feature_importances_
features = X_train_featured.columns
feature_importance = sorted(zip(importance, features), reverse=True)
print("\nFeature Importance:")
for imp, feat in feature_importance:
    print(f"{feat}: {imp:.4f}")

# Save the model
model.save_model('reimbursement_model.json')
print("Model saved to reimbursement_model.json")