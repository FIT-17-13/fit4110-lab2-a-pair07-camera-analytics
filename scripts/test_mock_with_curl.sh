#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:4010}"
AUTH_HEADER="Authorization: Bearer test-token"

echo "[Lab02] Testing Prism mock server at $BASE_URL"
echo

echo "[1/5] Happy path: GET /health"
curl -i "$BASE_URL/health"
echo
echo "---"

echo "[2/5] Happy path: GET /camera-events"
curl -i "$BASE_URL/camera-events" -H "$AUTH_HEADER"
echo
echo "---"

echo "[3/5] Happy path: POST /camera-events motion event"
curl -i -X POST "$BASE_URL/camera-events" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "eventId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "eventType": "camera.motion.detected",
    "occurredAt": "2026-05-19T10:00:00Z",
    "correlationId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "source": "camera-stream",
    "data": {
      "cameraId": "cam-01",
      "frameId": "frame-12345",
      "motionDetected": true,
      "motionConfidence": 0.91,
      "objectType": "person",
      "imageRef": "https://storage.campus.local/frames/frame-12345.jpg",
      "boundingBoxes": [],
      "zone": "entrance",
      "location": "Building A Gate"
    }
  }'
echo
echo "---"

echo "[4/5] Happy path: PUT /subscriptions/camera-events"
curl -i -X PUT "$BASE_URL/subscriptions/camera-events" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "consumerService": "analytics",
    "topics": [
      "camera.motion.detected",
      "camera.frame.analyzed",
      "camera.status.changed"
    ],
    "deliveryMode": "at_least_once",
    "deadLetterTopic": "analytics.camera-events.dlq",
    "maxRetryAttempts": 3
  }'
echo
echo "---"

echo "[5/5] Happy path: GET /analytics/camera-summary"
curl -i "$BASE_URL/analytics/camera-summary?cameraId=cam-01" -H "$AUTH_HEADER"
echo
