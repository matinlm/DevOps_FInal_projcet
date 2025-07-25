#!/bin/bash

# Load Testing Script for IceCream Application
# Requirements: 500 concurrent requests over 60 seconds

echo "🚀 IceCream Application Load Testing"
echo "===================================="

# Get the application URL
APP_URL=$(minikube service icecream-app-service --url)
echo "📍 Target URL: $APP_URL"

# Create results directory
mkdir -p load-test-results
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="load-test-results/results_${TIMESTAMP}.txt"
PERFORMANCE_FILE="load-test-results/performance_${TIMESTAMP}.txt"

echo "📊 Starting Load Test..."
echo "⏱️  Duration: 60 seconds"
echo "👥 Concurrent requests: 500"
echo "📁 Results will be saved to: $RESULTS_FILE"
echo ""

# Start monitoring in background
echo "🔍 Starting system monitoring..."
kubectl top pods > "$PERFORMANCE_FILE" 2>/dev/null &
MONITOR_PID=$!

# Function to make concurrent requests
make_requests() {
    local url=$1
    local num_requests=$2
    local output_file=$3
    
    for i in $(seq 1 $num_requests); do
        {
            start_time=$(date +%s.%N)
            response=$(curl -s -o /dev/null -w "%{http_code},%{time_total},%{time_connect},%{size_download}" "$url" 2>/dev/null)
            end_time=$(date +%s.%N)
            duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            echo "$i,$response,$duration" >> "$output_file"
        } &
    done
    wait
}

# Start load test
echo "🔥 Load test starting..."
start_test_time=$(date +%s)

# Create CSV header
echo "request_id,http_code,total_time,connect_time,size_download,duration" > "$RESULTS_FILE"

# Run load test - 500 requests over 60 seconds
# Split into batches to avoid overwhelming the system
BATCH_SIZE=50
TOTAL_REQUESTS=500
BATCHES=$((TOTAL_REQUESTS / BATCH_SIZE))

for batch in $(seq 1 $BATCHES); do
    echo "📈 Processing batch $batch/$BATCHES..."
    make_requests "$APP_URL" $BATCH_SIZE "$RESULTS_FILE"
    
    # Small delay between batches to spread over 60 seconds
    sleep 6
done

end_test_time=$(date +%s)
total_duration=$((end_test_time - start_test_time))

# Stop monitoring
kill $MONITOR_PID 2>/dev/null

echo ""
echo "✅ Load test completed!"
echo "⏱️  Total duration: ${total_duration} seconds"
echo "📊 Analyzing results..."

# Analyze results
if [ -f "$RESULTS_FILE" ]; then
    total_requests=$(wc -l < "$RESULTS_FILE")
    total_requests=$((total_requests - 1)) # Subtract header
    
    successful_requests=$(awk -F',' '$2 == 200 {count++} END {print count+0}' "$RESULTS_FILE")
    failed_requests=$((total_requests - successful_requests))
    
    avg_response_time=$(awk -F',' 'NR > 1 {sum += $3; count++} END {print sum/count}' "$RESULTS_FILE")
    
    echo ""
    echo "📈 LOAD TEST RESULTS"
    echo "===================="
    echo "Total requests: $total_requests"
    echo "Successful (200): $successful_requests"
    echo "Failed: $failed_requests"
    echo "Success rate: $(echo "scale=2; $successful_requests * 100 / $total_requests" | bc -l)%"
    echo "Average response time: ${avg_response_time}s"
    echo ""
    echo "📁 Detailed results saved to: $RESULTS_FILE"
    echo "📊 Performance data saved to: $PERFORMANCE_FILE"
else
    echo "❌ Results file not found!"
fi

# Show current pod status
echo ""
echo "🔍 Current Pod Status:"
kubectl get pods -l app=icecream-app
echo ""
echo "📊 Resource Usage:"
kubectl top pods -l app=icecream-app 2>/dev/null || echo "Metrics not available (requires metrics-server)"