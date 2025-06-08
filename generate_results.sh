#!/bin/bash

# Black Box Challenge - Parallel Results Generation Script
# This script runs your implementation against test cases in parallel threads

set -e

echo "🧾 Black Box Challenge - Generating Private Results (Parallel Version)"
echo "===================================================="
echo

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is required but not installed!"
    echo "Please install jq to parse JSON files:"
    echo "  macOS: brew install jq"
    echo "  Ubuntu/Debian: sudo apt-get install jq"
    echo "  CentOS/RHEL: sudo yum install jq"
    exit 1
fi

# Check if run.sh exists
if [ ! -f "run.sh" ]; then
    echo "❌ Error: run.sh not found!"
    echo "Please create a run.sh script that takes three parameters:"
    echo "  ./run.sh <trip_duration_days> <miles_traveled> <total_receipts_amount>"
    echo "  and outputs the reimbursement amount"
    exit 1
fi

# Make run.sh executable
chmod +x run.sh

# Check if private cases exist
if [ ! -f "private_cases.json" ]; then
    echo "❌ Error: private_cases.json not found!"
    echo "Please ensure the private cases file is in the current directory."
    exit 1
fi

echo "📊 Processing test cases and generating results in parallel..."
echo "📝 Output will be saved to private_results.txt"
echo

# Extract all test data upfront in a single jq call for better performance
echo "Extracting test data..."
total_cases=$(jq length private_cases.json)
echo "Found $total_cases test cases to process"

# Create a temporary directory for chunks
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

# Function to process a chunk of test cases
process_chunk() {
    local start=$1
    local end=$2
    local chunk_file="$temp_dir/results_${start}_${end}.txt"
    
    echo "Processing chunk $start to $end..." >&2
    
    for ((i=start; i<end; i++)); do
        if [ $((i % 20)) -eq 0 ] && [ $i -gt $start ]; then
            echo "Thread $(($start/chunk_size + 1)): $i/$end cases processed..." >&2
        fi
        
        # Extract test case data using jq for this specific index
        case_data=$(jq -r ".[$i] | \"\(.trip_duration_days):\(.miles_traveled):\(.total_receipts_amount)\"" private_cases.json)
        IFS=':' read -r trip_duration miles_traveled receipts_amount <<< "$case_data"
        
        # Run the user's implementation
        if script_output=$(./run.sh "$trip_duration" "$miles_traveled" "$receipts_amount" 2>/dev/null); then
            # Check if output is a valid number
            output=$(echo "$script_output" | tr -d '[:space:]')
            if [[ $output =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
                echo "$output" >> "$chunk_file"
            else
                echo "Error on case $((i+1)): Invalid output format: $output" >&2
                echo "ERROR" >> "$chunk_file"
            fi
        else
            # Capture stderr for error reporting
            error_msg=$(./run.sh "$trip_duration" "$miles_traveled" "$receipts_amount" 2>&1 >/dev/null | tr -d '\n')
            echo "Error on case $((i+1)): Script failed: $error_msg" >&2
            echo "ERROR" >> "$chunk_file"
        fi
    done
    
    echo "Chunk $start to $end completed" >&2
}

# Determine number of threads based on CPU cores
num_threads=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
# Limit to a reasonable number to avoid overwhelming the system
if [ "$num_threads" -gt 8 ]; then
    num_threads=8
fi
echo "Using $num_threads parallel threads"

# Calculate chunk size
chunk_size=$(( (total_cases + num_threads - 1) / num_threads ))
echo "Chunk size: $chunk_size cases per thread"

# Remove existing results file if it exists
rm -f private_results.txt

# Launch parallel processing
pids=()
for ((i=0; i<total_cases; i+=chunk_size)); do
    end=$((i + chunk_size))
    if [ $end -gt $total_cases ]; then
        end=$total_cases
    fi
    
    # Process this chunk in background
    process_chunk $i $end &
    pids+=($!)
    
    echo "Started thread for chunk $i to $end (PID: ${pids[-1]})"
done

# Wait for all background processes to complete
echo "Waiting for all threads to complete..."
for pid in "${pids[@]}"; do
    wait $pid
done

# Combine results in the correct order
echo "Combining results from all threads..."
for ((i=0; i<total_cases; i+=chunk_size)); do
    end=$((i + chunk_size))
    if [ $end -gt $total_cases ]; then
        end=$total_cases
    fi
    
    chunk_file="$temp_dir/results_${i}_${end}.txt"
    if [ -f "$chunk_file" ]; then
        cat "$chunk_file" >> private_results.txt
    else
        echo "Warning: Missing results for chunk $i to $end" >&2
        # Add ERROR entries for the missing chunk
        for ((j=i; j<end; j++)); do
            echo "ERROR" >> private_results.txt
        done
    fi
done

# Verify the correct number of results
result_count=$(wc -l < private_results.txt)
if [ "$result_count" -ne "$total_cases" ]; then
    echo "⚠️ Warning: Expected $total_cases results but got $result_count" >&2
    # Pad with errors if needed
    while [ "$result_count" -lt "$total_cases" ]; do
        echo "ERROR" >> private_results.txt
        result_count=$((result_count + 1))
    done
fi

echo
echo "✅ Results generated successfully!" >&2
echo "📄 Output saved to private_results.txt" >&2
echo "📊 Each line contains the result for the corresponding test case in private_cases.json" >&2

echo
echo "🎯 Next steps:"
echo "  1. Check private_results.txt - it should contain one result per line"
echo "  2. Each line corresponds to the same-numbered test case in private_cases.json"
echo "  3. Lines with 'ERROR' indicate cases where your script failed"
echo "  4. Submit your private_results.txt file when ready!"
echo
echo "📈 File format:"
echo "  Line 1: Result for private_cases.json[0]"
echo "  Line 2: Result for private_cases.json[1]" 
echo "  Line 3: Result for private_cases.json[2]"
echo "  ..."
echo "  Line N: Result for private_cases.json[N-1]" 