# Biên bản đàm phán hợp đồng API

- Cặp đàm phán: Camera Stream → Analytics
- Product: Smart Campus Operations Platform
- Provider: Camera Stream
- Consumer: Analytics
- Phiên: v1.0
- Ngày: 2026-05-19

---

## Issue #1

- Raised by: Consumer
- Endpoint: Event `camera.motion.detected`
- Concern: Analytics cần đủ thông tin để thống kê motion và xác định camera nguồn
- Proposal: Payload bắt buộc gồm `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `data.cameraId`, `data.frameId`, `data.motionDetected`, `data.motionConfidence`, `data.imageRef`
- Resolution: Accepted
- Rationale: Đảm bảo Analytics có dữ liệu tối thiểu để xử lý và tránh gửi ảnh binary
- Impact: Provider phải chỉ gửi `imageRef`, không gửi ảnh nhúng

---

## Issue #2

- Raised by: Consumer
- Endpoint: Event `camera.frame.analyzed`
- Concern: Analytics cần một event bổ sung cho kết quả phân tích frame
- Proposal: Payload bao gồm `cameraId`, `frameId`, `objectCount`, `detectedObjects`, `analysisStatus`, optional `imageRef`
- Resolution: Accepted
- Rationale: Giúp Analytics cập nhật số lượng đối tượng và trạng thái phân tích mà không cần REST call thêm
- Impact: Provider cần xác định rõ `analysisStatus` và cấu trúc `detectedObjects`

---

## Issue #3

- Raised by: Consumer
- Endpoint: Event `camera.status.changed`
- Concern: Analytics cần trạng thái camera để giám sát offline/online
- Proposal: Payload gồm `cameraId`, `status`, `reason`, `lastSeen`, optional `cpuUsage`, `memoryUsage`, `signalStrength`
- Resolution: Accepted
- Rationale: Cho phép dashboard trạng thái camera chính xác và cảnh báo kịp thời
- Impact: Provider bổ sung trường `status` và `reason` rõ ràng

---

## Issue #4

- Raised by: Consumer
- Endpoint: Tất cả event
- Concern: Event duplicate / retry có thể dẫn đến thống kê sai
- Proposal: Bổ sung quy định bắt buộc `eventId` và `correlationId`, consumer sẽ dùng chúng để idempotent
- Resolution: Accepted
- Rationale: Idempotency cần thiết cho xử lý async
- Impact: Provider phải sinh `eventId` duy nhất cho mỗi event, và `correlationId` cho luồng detection nếu có

---

## Issue #5

- Raised by: Consumer
- Endpoint: Tất cả event
- Concern: `occurredAt` không đúng định dạng sẽ gây sai thứ tự xử lý
- Proposal: Quy định timestamp dùng UTC ISO 8601, ví dụ `2026-05-19T10:00:00Z`
- Resolution: Accepted
- Rationale: Đảm bảo ordering và so sánh thời gian nhất quán giữa services
- Impact: Provider phải chuẩn hoá timestamp trước khi publish

---

## Issue #6

- Raised by: Provider
- Endpoint: Event `camera.motion.detected`
- Concern: Có cần gửi `confidence` và `boundingBoxes` trong motion event không?
- Proposal: Gửi `motionConfidence` là bắt buộc, `boundingBoxes` là optional nếu provider có dữ liệu
- Resolution: Accepted (confidence required, boundingBoxes optional)
- Rationale: Confidence quan trọng cho phân tích abnormal, bounding boxes có thể tối ưu sau
- Impact: Provider có thể publish event nhẹ hơn nếu không có bounding box

---

# Chốt hợp đồng v1.0

Provider sign-off:  
Consumer sign-off:  
Witness (GV/TA):    
Date: 2026-05-19

---

## Ghi chú warning nếu Spectral còn cảnh báo

| Warning | Lý do chấp nhận tạm thời | Kế hoạch sửa |
|---|---|---|
| Nếu còn warning do schema event chưa đủ chi tiết | Đang chấp nhận hợp đồng sơ bộ Lab 02 và tiếp tục hoàn thiện ở Lab 03 | Bổ sung AsyncAPI/topic schema và payload schema trong Lab 03 |
