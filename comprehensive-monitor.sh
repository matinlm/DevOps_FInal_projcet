#!/bin/bash

# Comprehensive Monitoring Script for Load Testing
# Run this in parallel with your load tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
MONITOR_INTERVAL=10
LOG_DIR="load-test-results/monitoring"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create monitoring directory
mkdir -p "$LOG_DIR"

# Log files
POD_LOG="$LOG_DIR/pod-status-${TIMESTAMP}.csv"
RESOURCE_LOG="$LOG_DIR/resource-usage-${TIMESTAMP}.csv"
EVENT_LOG="$LOG_DIR/events-${TIMESTAMP}.log"
APP_LOG="$LOG_DIR/application-${TIMESTAMP}.log"
SUMMARY_LOG="$LOG_DIR/summary-${TIMESTAMP}.log"

print_header() {
    clear
    echo -e "${BLUE}🔍 Real-time Kubernetes Monitoring Dashboard${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${CYAN}📅 Started: $(date)${NC}"
    echo -e "${CYAN}📁 Logs: $LOG_DIR${NC}"
    echo ""
}

print_section() {
    echo -e "${YELLOW}$1${NC}"
    echo "$(printf '=%.0s' {1..50})"
}

# Initialize CSV files with headers
init_csv_files() {
    echo "timestamp,pod_name,status,ready,restarts,age,cpu_usage,memory_usage" > "$POD_LOG"
    echo "timestamp,total_pods,ready_pods,pending_pods,failed_pods,total_cpu,total_memory,node_cpu,node_memory" > "$RESOURCE_LOG"
}

# Monitor pod status
monitor_pods() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get pod information
    kubectl get pods -l app=icecream-app --no-headers | while read line; do
        if [ -n "$line" ]; then
            pod_name=$(echo $line | awk '{print $1}')
            ready=$(echo $line | awk '{print $2}')
            status=$(echo $line | awk '{print $3}')
            restarts=$(echo $line | awk '{print $4}')
            age=$(echo $line | awk '{print $5}')
            
            # Get resource usage
            resource_info=$(kubectl top pod $pod_name --no-headers 2>/dev/null || echo "N/A N/A")
            cpu_usage=$(echo $resource_info | awk '{print $2}')
            memory_usage=$(echo $resource_info | awk '{print $3}')
            
            # Log to CSV
            echo "$timestamp,$pod_name,$status,$ready,$restarts,$age,$cpu_usage,$memory_usage" >> "$POD_LOG"
        fi
    done
}

# Monitor overall resource usage
monitor_resources() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Count pods by status
    local total_pods=$(kubectl get pods -l app=icecream-app --no-headers | wc -l)
    local ready_pods=$(kubectl get pods -l app=icecream-app --no-headers | grep "Running" | wc -l)
    local pending_pods=$(kubectl get pods -l app=icecream-app --no-headers | grep "Pending" | wc -l)
    local failed_pods=$(kubectl get pods -l app=icecream-app --no-headers | grep -E "(Failed|Error|CrashLoopBackOff)" | wc -l)
    
    # Get total resource usage
    local resource_summary=$(kubectl top pods -l app=icecream-app --no-headers 2>/dev/null | awk '{cpu+=$2; mem+=$3} END {print cpu "m " mem "Mi"}')
    local total_cpu=$(echo $resource_summary | awk '{print $1}')
    local total_memory=$(echo $resource_summary | awk '{print $2}')
    
    # Get node resource usage
    local node_resources=$(kubectl top nodes --no-headers 2>/dev/null | head -1 | awk '{print $2 " " $4}')
    local node_cpu=$(echo $node_resources | awk '{print $1}')
    local node_memory=$(echo $node_resources | awk '{print $2}')
    
    # Log to CSV
    echo "$timestamp,$total_pods,$ready_pods,$pending_pods,$failed_pods,$total_cpu,$total_memory,$node_cpu,$node_memory" >> "$RESOURCE_LOG"
}

# Monitor events
monitor_events() {
    kubectl get events --sort-by=.metadata.creationTimestamp --no-headers 2>/dev/null | tail -20 >> "$EVENT_LOG"
}

# Monitor application logs
monitor_app_logs() {
    kubectl logs -l app=icecream-app --tail=50 --since=30s 2>/dev/null | while read line; do
        if [ -n "$line" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') $line" >> "$APP_LOG"
        fi
    done
}

# Display real-time dashboard
display_dashboard() {
    print_header
    
    # Pod Status Section
    print_section "📦 Pod Status"
    kubectl get pods -l app=icecream-app 2>/dev/null || echo "No pods found"
    echo ""
    
    # Resource Usage Section
    print_section "💾 Resource Usage"
    kubectl top pods -l app=icecream-app 2>/dev/null || echo "Resource metrics not available"
    echo ""
    
    # Node Status Section
    print_section "🖥️  Node Status"
    kubectl top nodes 2>/dev/null || echo "Node metrics not available"
    echo ""
    
    # Service Status Section
    print_section "🌐 Service Status"
    kubectl get services -l app=icecream-app 2>/dev/null || echo "No services found"
    echo ""
    
    # Recent Events Section
    print_section "📋 Recent Events (Last 5)"
    kubectl get events --sort-by=.metadata.creationTimestamp --no-headers 2>/dev/null | grep icecream | tail -5 || echo "No recent events"
    echo ""
    
    # MongoDB Status Section
    print_section "🗄️  MongoDB Status"
    kubectl get pods -l app=mongodb 2>/dev/null || echo "MongoDB not found"
    echo ""
    
    # Summary Statistics
    print_section "📊 Summary Statistics"
    local total_pods=$(kubectl get pods -l app=icecream-app --no-headers 2>/dev/null | wc -l)
    local ready_pods=$(kubectl get pods -l app=icecream-app --no-headers 2>/dev/null | grep "Running" | wc -l)
    local failed_pods=$(kubectl get pods -l app=icecream-app --no-headers 2>/dev/null | grep -E "(Failed|Error|CrashLoopBackOff)" | wc -l)
    
    echo -e "Total Pods: ${CYAN}$total_pods${NC}"
    echo -e "Ready Pods: ${GREEN}$ready_pods${NC}"
    echo -e "Failed Pods: ${RED}$failed_pods${NC}"
    
    if [ "$failed_pods" -gt 0 ]; then
        echo -e "${RED}⚠️  WARNING: Some pods have failed!${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Press Ctrl+C to stop monitoring${NC}"
    echo -e "${CYAN}Next update in $MONITOR_INTERVAL seconds...${NC}"
}

# Health check function
perform_health_check() {
    local app_url=$(minikube service icecream-app-service --url 2>/dev/null)
    if [ -n "$app_url" ]; then
        local response=$(curl -s -w "%{http_code}" -o /dev/null "$app_url" 2>/dev/null)
        if [ "$response" = "200" ]; then
            echo -e "${GREEN}✅ Application is responding (HTTP 200)${NC}"
        else
            echo -e "${RED}❌ Application health check failed (HTTP $response)${NC}"
        fi
    else
        echo -e "${RED}❌ Cannot get application URL${NC}"
    fi
}

# Simulate container crash (for fault tolerance testing)
simulate_crash() {
    echo -e "${YELLOW}🔥 Simulating container crash...${NC}"
    
    # Get a random pod
    local pod_name=$(kubectl get pods -l app=icecream-app --no-headers | head -1 | awk '{print $1}')
    
    if [ -n "$pod_name" ]; then
        echo -e "${YELLOW}Killing pod: $pod_name${NC}"
        kubectl delete pod "$pod_name"
        echo -e "${YELLOW}Pod killed. Monitoring recovery...${NC}"
        
        # Monitor recovery
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Pod $pod_name killed for fault tolerance test" >> "$SUMMARY_LOG"
    else
        echo -e "${RED}No pods found to kill${NC}"
    fi
}

# Generate summary report
generate_summary() {
    echo -e "${BLUE}📄 Generating monitoring summary...${NC}"
    
    cat > "$SUMMARY_LOG" << EOF
=== IceCream Load Test Monitoring Summary ===
Generated: $(date)
Duration: Started at $TIMESTAMP

=== Pod Statistics ===
Total monitoring records: $(wc -l < "$POD_LOG")
Resource monitoring records: $(wc -l < "$RESOURCE_LOG")

=== Key Observations ===
EOF

    # Analyze pod restarts
    local max_restarts=$(tail -n +2 "$POD_LOG" | cut -d',' -f5 | sort -n | tail -1)
    echo "Maximum pod restarts observed: $max_restarts" >> "$SUMMARY_LOG"
    
    # Check for failures
    local failure_count=$(grep -c -E "(Failed|Error|CrashLoopBackOff)" "$POD_LOG" 2>/dev/null || echo "0")
    echo "Pod failure events: $failure_count" >> "$SUMMARY_LOG"
    
    echo "=== Files Generated ===" >> "$SUMMARY_LOG"
    echo "Pod status log: $POD_LOG" >> "$SUMMARY_LOG"
    echo "Resource usage log: $RESOURCE_LOG" >> "$SUMMARY_LOG"
    echo "Events log: $EVENT_LOG" >> "$SUMMARY_LOG"
    echo "Application log: $APP_LOG" >> "$SUMMARY_LOG"
    
    echo -e "${GREEN}✅ Summary saved to: $SUMMARY_LOG${NC}"
}

# Signal handlers
cleanup() {
    echo -e "\n${YELLOW}🛑 Stopping monitoring...${NC}"
    generate_summary
    echo -e "${GREEN}✅ Monitoring data saved to: $LOG_DIR${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main monitoring loop
main() {
    echo -e "${BLUE}🚀 Starting comprehensive monitoring...${NC}"
    echo -e "${CYAN}📁 Results will be saved to: $LOG_DIR${NC}"
    
    # Initialize CSV files
    init_csv_files
    
    # Ask if user wants to simulate crashes
    echo ""
    read -p "Enable fault tolerance testing (simulate crashes)? (y/n): " -n 1 -r
    echo ""
    ENABLE_CRASH_SIM=$REPLY
    
    echo -e "${GREEN}✅ Monitoring started! Press Ctrl+C to stop.${NC}"
    sleep 2
    
    local iteration=0
    
    while true; do
        # Collect monitoring data
        monitor_pods
        monitor_resources
        monitor_events
        monitor_app_logs
        
        # Display dashboard
        display_dashboard
        
        # Perform health check
        perform_health_check
        
        # Simulate crash every 10 iterations (if enabled)
        if [[ $ENABLE_CRASH_SIM =~ ^[Yy]$ ]] && [ $((iteration % 10)) -eq 9 ] && [ $iteration -gt 0 ]; then
            simulate_crash
        fi
        
        # Wait for next iteration
        sleep $MONITOR_INTERVAL
        iteration=$((iteration + 1))
    done
}

# Run main function
main