#!/bin/bash

# Resource Monitoring Script
# Run this in a separate terminal during load testing

echo "🔍 Real-time Pod and Resource Monitoring"
echo "========================================"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="load-test-results/monitoring_${TIMESTAMP}.log"

echo "📁 Monitoring data will be saved to: $LOG_FILE"
echo "Press Ctrl+C to stop monitoring"
echo ""

# Create monitoring log with headers
echo "timestamp,pod_name,cpu_usage,memory_usage,restarts,status" > "$LOG_FILE"

while true; do
    current_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get pod information
    kubectl get pods -l app=icecream-app --no-headers | while read line; do
        pod_name=$(echo $line | awk '{print $1}')
        restarts=$(echo $line | awk '{print $4}')
        status=$(echo $line | awk '{print $3}')
        
        # Get resource usage (if metrics-server is available)
        resource_info=$(kubectl top pod $pod_name --no-headers 2>/dev/null)
        if [ $? -eq 0 ]; then
            cpu_usage=$(echo $resource_info | awk '{print $2}')
            memory_usage=$(echo $resource_info | awk '{print $3}')
        else
            cpu_usage="N/A"
            memory_usage="N/A"
        fi
        
        # Log the data
        echo "$current_time,$pod_name,$cpu_usage,$memory_usage,$restarts,$status" >> "$LOG_FILE"
        
        # Display on screen
        printf "%-20s | %-30s | CPU: %-8s | Memory: %-8s | Restarts: %-3s | Status: %s\n" \
               "$current_time" "$pod_name" "$cpu_usage" "$memory_usage" "$restarts" "$status"
    done
    
    echo "----------------------------------------"
    sleep 5
done