#!/bin/bash

# Debug script to check what's happening with prerequisites
set -x  # Enable debug mode

echo "=== Checking Minikube Status ==="
minikube status
echo "Exit code: $?"

echo ""
echo "=== Checking if Minikube is running ==="
if minikube status > /dev/null 2>&1; then
    echo "Minikube is running"
else
    echo "Minikube is NOT running"
fi

echo ""
echo "=== Checking Kubernetes context ==="
kubectl config current-context

echo ""
echo "=== Checking all pods ==="
kubectl get pods --all-namespaces

echo ""
echo "=== Checking IceCream pods specifically ==="
kubectl get pods -l app=icecream-app --no-headers 2>/dev/null
echo "Exit code: $?"

echo ""
echo "=== Counting ready pods ==="
ready_pods=$(kubectl get pods -l app=icecream-app --no-headers 2>/dev/null | grep "Running" | wc -l)
echo "Ready pods count: $ready_pods"

echo ""
echo "=== Checking service ==="
kubectl get services
echo ""
minikube service list

echo ""
echo "=== Testing service URL ==="
app_url=$(minikube service icecream-app-service --url 2>/dev/null)
echo "App URL: $app_url"

if [ -n "$app_url" ]; then
    echo "Testing connectivity to: $app_url"
    curl -s --max-time 5 "$app_url" || echo "Curl failed with exit code: $?"
else
    echo "Could not get app URL"
fi