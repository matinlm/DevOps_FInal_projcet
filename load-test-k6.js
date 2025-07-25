import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics
const httpReqFailed = new Rate('http_req_failed');
const customHttpReqDuration = new Trend('custom_http_req_duration'); // Renamed to avoid conflict
const stationsRequests = new Counter('stations_requests');

// Test configuration
export const options = {
  stages: [
    { duration: '10s', target: 100 }, // Ramp up to 100 users
    { duration: '20s', target: 300 }, // Ramp up to 300 users
    { duration: '30s', target: 500 }, // Peak at 500 users
    { duration: '60s', target: 500 }, // Hold at peak
    { duration: '10s', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests < 2s
    http_req_failed: ['rate<0.1'],     // < 10% failure rate
  },
};

// Get the Minikube service URL
const BASE_URL = __ENV.BASE_URL || 'http://192.168.49.2:30000';

export default function () {
  const scenarios = [
    { name: 'Home Page', url: `${BASE_URL}/`, weight: 40 },
    { name: 'Stations List', url: `${BASE_URL}/stations`, weight: 30 },
    { name: 'Add Station', url: `${BASE_URL}/stations/add`, weight: 20 },
    { name: 'View Station', url: `${BASE_URL}/stations/1`, weight: 10 },
  ];

  const randomScenario = scenarios[Math.floor(Math.random() * scenarios.length)];

  const response = http.get(randomScenario.url, {
    headers: {
      'User-Agent': 'k6-load-test/1.0',
      'Accept': 'application/json, text/html',
    },
    timeout: '30s',
  });

  // Custom metrics
  httpReqFailed.add(response.status !== 200);
  customHttpReqDuration.add(response.timings.duration);

  if (randomScenario.name === 'Stations List') {
    stationsRequests.add(1);
  }

  // Assertions
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 5000ms': (r) => r.timings.duration < 5000,
    'response has content': (r) => r.body.length > 0,
  });

  sleep(Math.random() * 2 + 1);
}

// Setup - runs once before the test
export function setup() {
  console.log('🚀 Starting IceCream Load Test');
  console.log(`📍 Target URL: ${BASE_URL}`);
  console.log('⏱️  Duration: 60 seconds at 500 concurrent users');

  const response = http.get(`${BASE_URL}/`);
  if (response.status !== 200) {
    throw new Error(`Application not accessible: ${response.status}`);
  }
  console.log('✅ Application is accessible');

  return { baseUrl: BASE_URL };
}

// Teardown - runs once after the test
export function teardown(data) {
  console.log('🏁 Load test completed');
  console.log(`📊 Target URL was: ${data.baseUrl}`);
}
