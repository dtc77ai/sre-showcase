import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 20 },   // Quick ramp to 20 users
    { duration: '90s', target: 150 },  // Spike to 150 users (more aggressive)
    { duration: '30s', target: 20 },   // Ramp down
    { duration: '10s', target: 0 },    // Cool down
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'],  // Relaxed threshold
    http_req_failed: ['rate<0.1'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8000';

export default function () {
  // Mix of endpoints for varied load
  const endpoints = ['/api/data', '/api/status', '/'];
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  
  const res = http.get(`${BASE_URL}${endpoint}`);
  
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 1000ms': (r) => r.timings.duration < 1000,
  });
  
  sleep(0.5);  // Reduced sleep = more requests per user
}
