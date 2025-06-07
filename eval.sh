#!/bin/bash

# Black Box Challenge Evaluation Script
# This script tests your reimbursement calculation implementation against 1,000 historical cases

set -e

# Define log file
LOG_FILE="reimbursement_evaluation_$(date +%Y%m%d_%H%M%S).log"

# Function to log output to both console and log file
log() {
    echo "$@" | tee -a "$LOG_FILE"
}

log "🧾 Black Box Challenge - Reimbursement System Evaluation"
log "======================================================="
log ""

# Check if jq is available
if ! command -v jq &> /dev/null; then
    log "❌ Error: jq is required but not installed!"
    log "Please install jq to parse JSON files:"
    log "  macOS: brew install jq"
    log "  Ubuntu/Debian: sudo apt-get install jq"
    log "  CentOS/RHEL: sudo yum install jq"
    exit 1
fi

# Check if bc is available for floating point arithmetic
if ! command -v bc &> /dev/null; then
    log "❌ Error: bc (basic calculator) is required but not installed!"
    log "Please install bc for floating point calculations:"
    log "  macOS: brew install bc"
    log "  Ubuntu/Debian: sudo apt-get install bc"
    log "  CentOS/RHEL: sudo yum install bc"
    exit 1
fi

# Check if run.sh exists
if [ ! -f "run.sh" ]; then
    log "❌ Error: run.sh not found!"
    log "Please create a run.sh script that takes three parameters:"
    log "  ./run.sh <trip_duration_days> <miles_traveled> <total_receipts_amount>"
    log "  and outputs the reimbursement amount"
    exit 1
fi

# Make run.sh executable
chmod +x run.sh

# Check if public cases exist
if [ ! -f "public_cases.json" ]; then
    log "❌ Error: public_cases.json not found!"
    log "Please ensure the public cases file is in the current directory."
    exit 1
fi

log "📊 Running evaluation against 1,000 test cases..."
log ""

# Extract all test data upfront in a single jq call for better performance
log "Extracting test data..." | tee -a "$LOG_FILE"
test_data=$(jq -r '.[] | "\(.input.trip_duration_days):\(.input.miles_traveled):\(.input.total_receipts_amount):\(.expected_output)"' public_cases.json)

# Convert to arrays for faster access (compatible with bash 3.2+)
test_cases=()
while IFS= read -r line; do
    test_cases+=("$line")
done <<< "$test_data"
num_cases=${#test_cases[@]}

# Initialize counters and arrays
successful_runs=0
exact_matches=0
close_matches=0
total_error="0"
max_error="0"
max_error_case=""
results_array=()
errors_array=()
total_time=0

# Process each test case
for ((i=0; i<num_cases; i++)); do
    if [ $((i % 100)) -eq 0 ]; then
        echo "Progress: $i/$num_cases cases processed..." >&2
    fi
    
    # Extract test case data from pre-loaded array
    IFS=':' read -r trip_duration miles_traveled receipts_amount expected <<< "${test_cases[i]}"

    # Measure start time in seconds with nanosecond precision
    start_time=$(date +%s.%N)
    
    # Run the user's implementation
    if script_output=$(./run.sh "$trip_duration" "$miles_traveled" "$receipts_amount" 2>/dev/null); then

        # Measure end time and compute duration
        end_time=$(date +%s.%N)
        exec_time=$(echo "$end_time - $start_time" | bc)
        total_time=$(echo "$total_time + $exec_time" | bc)

        # Print the output for debugging
        log "Case $((i+1)): Trip Duration: $trip_duration days, Miles Traveled: $miles_traveled, Receipts Amount: \$$receipts_amount"
        log "Expected Output: \$$expected"
        log "Actual Output: $script_output"
        log "⏱️  Execution time: ${exec_time} s"
        # Check if output is a valid number
        output=$(echo "$script_output" | tr -d '[:space:]')
        if [[ $output =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
            actual="$output"
            
            # Calculate absolute error using bc
            error=$(echo "scale=10; if ($actual - $expected < 0) -1 * ($actual - $expected) else ($actual - $expected)" | bc)

            # Print error for this case
            log "📉 Error: \$${error}"            
            
            # Store result in memory array
            results_array+=("$((i+1)):$expected:$actual:$error:$trip_duration:$miles_traveled:$receipts_amount")
            
            successful_runs=$((successful_runs + 1))
            
            # Check for exact match (within $0.01)
            if (( $(echo "$error < 0.01" | bc -l) )); then
                exact_matches=$((exact_matches + 1))
            fi
            
            # Check for close match (within $1.00)
            if (( $(echo "$error < 1.0" | bc -l) )); then
                close_matches=$((close_matches + 1))
            fi
            
            # Update total error
            total_error=$(echo "scale=10; $total_error + $error" | bc)
            
            # Track maximum error
            if (( $(echo "$error > $max_error" | bc -l) )); then
                max_error="$error"
                max_error_case="Case $((i+1)): $trip_duration days, $miles_traveled miles, \$$receipts_amount receipts"
            fi
            
        else
            errors_array+=("Case $((i+1)): Invalid output format: $output")
        fi
        log "----------------------------------------"
        log ""
    else
        # Capture stderr for error reporting
        error_msg=$(./run.sh "$trip_duration" "$miles_traveled" "$receipts_amount" 2>&1 >/dev/null | tr -d '\n')
        errors_array+=("Case $((i+1)): Script failed with error: $error_msg")
    fi
done

# Calculate and display results
if [ $successful_runs -eq 0 ]; then
    log "❌ No successful test cases!"
    log ""
    log "Your script either:"
    log "  - Failed to run properly"
    log "  - Produced invalid output format"
    log "  - Timed out on all cases"
    log ""
    log "Check the errors below for details."
else
    # Calculate average error
    avg_error=$(echo "scale=2; $total_error / $successful_runs" | bc)
    
    # Calculate percentages
    exact_pct=$(echo "scale=1; $exact_matches * 100 / $successful_runs" | bc)
    close_pct=$(echo "scale=1; $close_matches * 100 / $successful_runs" | bc)
    
    log "✅ Evaluation Complete!"
    log ""
    log "📈 Results Summary:"
    log "  Total test cases: $num_cases"
    log "  Successful runs: $successful_runs"
    log "  Exact matches (±\$0.01): $exact_matches (${exact_pct}%)"
    log "  Close matches (±\$1.00): $close_matches (${close_pct}%)"
    log "  Average error: \$${avg_error}"
    log "  Maximum error: \$${max_error}"
    log ""
    
    # Calculate score (lower is better)
    score=$(echo "scale=2; $avg_error * 100 + ($num_cases - $exact_matches) * 0.1" | bc)
    log "🎯 Your Score: $score (lower is better)"
    log ""
    
    # Provide feedback based on exact matches
    if [ $exact_matches -eq $num_cases ]; then
        log "🏆 PERFECT SCORE! You have reverse-engineered the system completely!"
    elif [ $exact_matches -gt 950 ]; then
        log "🥇 Excellent! You are very close to the perfect solution."
    elif [ $exact_matches -gt 800 ]; then
        log "🥈 Great work! You have captured most of the system behavior."
    elif [ $exact_matches -gt 500 ]; then
        log "🥉 Good progress! You understand some key patterns."
    else
        log "📚 Keep analyzing the patterns in the interviews and test cases."
    fi
    
    log ""
    log "💡 Tips for improvement:"
    if [ $exact_matches -lt $num_cases ]; then
        log "  Check these high-error cases:"
        
        # Sort results by error (descending) in memory and show top 5
        IFS=$'\n' high_error_cases=($(printf '%s\n' "${results_array[@]}" | sort -t: -k4 -nr | head -5))
        for result in "${high_error_cases[@]}"; do
            IFS=: read -r case_num expected actual error trip_duration miles_traveled receipts_amount <<< "$result"
            printf "    Case %s: %s days, %s miles, \$%s receipts\n" "$case_num" "$trip_duration" "$miles_traveled" "$receipts_amount" | tee -a "$LOG_FILE"
            printf "      Expected: \$%.2f, Got: \$%.2f, Error: \$%.2f\n" "$expected" "$actual" "$error" | tee -a "$LOG_FILE"
        done
    fi
fi

# Show errors if any
if [ ${#errors_array[@]} -gt 0 ]; then
    log ""
    log "⚠️  Errors encountered:"
    for ((j=0; j<${#errors_array[@]} && j<10; j++)); do
        log "  ${errors_array[j]}"
    done
    if [ ${#errors_array[@]} -gt 10 ]; then
        log "  ... and $((${#errors_array[@]} - 10)) more errors"
    fi
fi

log ""
log "📝 Next steps:"
log "  1. Fix any script errors shown above"
log "  2. Ensure your run.sh outputs only a number"
log "  3. Analyze the patterns in the interviews and public cases"
log "  4. Test edge cases around trip length and receipt amounts"
log "  5. Submit your solution via the Google Form when ready!"

log ""
log "📋 Complete evaluation log saved to: $LOG_FILE"