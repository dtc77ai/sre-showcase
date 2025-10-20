import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 50 },    // Ramp up to 50
    { duration: '2m', target: 100 },   // Ramp up to 100
    { duration: '2m', target: 200 },   // Ramp up to 200
    { duration: '2m', target: 300 },   // Ramp up to 300
    { duration: '2m', target: 400 },   // Push to 400 (find breaking point)
    { duration: '2m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],  // Relaxed threshold
    http_req_failed: ['rate<0.2'],      // Allow 20% failures
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8000';

export default function () {
  const res = http.get(`${BASE_URL}/api/data`);
  
  check(res, {
    'status is 200': (r) => r.status === 200,
  });
  
  sleep(0.5);
}
