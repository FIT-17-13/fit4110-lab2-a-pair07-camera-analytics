$ErrorActionPreference = "Stop"

$BaseUrl = if ($env:BASE_URL) { $env:BASE_URL } else { "http://localhost:4010" }
$AuthHeader = "Authorization: Bearer test-token"
$MotionPayloadFile = Join-Path $env:TEMP "lab02-motion-event.json"
$SubscriptionPayloadFile = Join-Path $env:TEMP "lab02-camera-subscription.json"

Write-Host "[Lab02] Testing Prism mock server at $BaseUrl"
Write-Host ""

Write-Host "[1/5] Happy path: GET /health"
curl.exe -i "$BaseUrl/health"
Write-Host "`n---"

Write-Host "[2/5] Happy path: GET /camera-events"
curl.exe -i "$BaseUrl/camera-events" -H $AuthHeader
Write-Host "`n---"

Write-Host "[3/5] Happy path: POST /camera-events motion event"
$motionPayload = '{"eventId":"f47ac10b-58cc-4372-a567-0e02b2c3d479","eventType":"camera.motion.detected","occurredAt":"2026-05-19T10:00:00Z","correlationId":"3fa85f64-5717-4562-b3fc-2c963f66afa6","source":"camera-stream","data":{"cameraId":"cam-01","frameId":"frame-12345","motionDetected":true,"motionConfidence":0.91,"objectType":"person","imageRef":"https://storage.campus.local/frames/frame-12345.jpg","boundingBoxes":[],"zone":"entrance","location":"Building-A-Gate"}}'
Set-Content -LiteralPath $MotionPayloadFile -Value $motionPayload -Encoding ASCII
curl.exe -i -X POST "$BaseUrl/camera-events" -H $AuthHeader -H "Content-Type: application/json" --data-binary "@$MotionPayloadFile"
Write-Host "`n---"

Write-Host "[4/5] Happy path: PUT /subscriptions/camera-events"
$subscriptionPayload = '{"consumerService":"analytics","topics":["camera.motion.detected","camera.frame.analyzed","camera.status.changed"],"deliveryMode":"at_least_once","deadLetterTopic":"analytics.camera-events.dlq","maxRetryAttempts":3}'
Set-Content -LiteralPath $SubscriptionPayloadFile -Value $subscriptionPayload -Encoding ASCII
curl.exe -i -X PUT "$BaseUrl/subscriptions/camera-events" -H $AuthHeader -H "Content-Type: application/json" --data-binary "@$SubscriptionPayloadFile"
Write-Host "`n---"

Write-Host "[5/5] Happy path: GET /analytics/camera-summary"
curl.exe -i "$BaseUrl/analytics/camera-summary?cameraId=cam-01" -H $AuthHeader
Write-Host ""
