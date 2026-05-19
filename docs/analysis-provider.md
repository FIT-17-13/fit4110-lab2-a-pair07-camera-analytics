# Phân tích yêu cầu — vai Provider

- Cặp đàm phán: pair-07 Camera Stream → Analytics
- Product: Smart Campus
- Provider service: Camera Stream
- Consumer service: Analytics
- Người viết: Nhóm 07
- Ngày: 2026-05-19

---

## 1. Tài nguyên chính

| Resource | Mô tả | Thuộc tính bắt buộc | Thuộc tính tùy chọn |
|---|---|---|---|
| `camera.motion.detected` | Event báo motion được phát hiện trên camera | `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `cameraId`, `frameId`, `motionDetected`, `motionConfidence` | `objectType`, `imageRef`, `boundingBoxes`, `zone`, `location` |
| `camera.frame.analyzed` | Event báo frame đã được phân tích xong | `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `cameraId`, `frameId`, `objectCount`, `detectedObjects`, `analysisStatus` | `imageRef`, `processingTime`, `metadata` |
| `camera.status.changed` | Event báo trạng thái camera thay đổi | `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `cameraId`, `status`, `reason`, `lastSeen` | `cpuUsage`, `memoryUsage`, `signalStrength`, `healthMetrics` |

---

## 2. Hình thức publish event

| Method | Topic / EventType | Mục đích | Kịch bản publish |
|---|---|---|---|
| PUBLISH | `camera.motion.detected` | Gửi event motion để Analytics cập nhật thống kê | Khi motion confidence vượt ngưỡng |
| PUBLISH | `camera.frame.analyzed` | Gửi kết quả phân tích frame cho Analytics | Khi frame xử lý xong và object detection hoàn tất |
| PUBLISH | `camera.status.changed` | Gửi trạng thái camera để giám sát health | Khi camera online/offline/error hoặc health metric thay đổi |

---

## 3. Error case Producer cần dự đoán

| Tình huống | Hiệu ứng | Xử lý dự kiến |
|---|---|---|
| Payload JSON không hợp lệ | Broker hoặc consumer reject | Log lỗi, drop event hoặc gửi DLQ nếu broker hỗ trợ |
| Thiếu trường bắt buộc như `cameraId`, `eventType` | Event không dùng được | Reject event, log error, cảnh báo sửa payload |
| `occurredAt` sai định dạng | Consumer không xác định thứ tự event | Chuẩn hoá timestamp ISO 8601 UTC trước khi publish |
| `status` không thuộc enum | Consumer hiểu sai trạng thái | Chuyển thành `error` hoặc `unknown`, cập nhật contract enum |
| Event duplicate do retry | Consumer xử lý lặp | Gửi tiếp `eventId`/`correlationId`, cho phép consumer dedupe |
| Payload quá lớn do ảnh nhúng | Broker timeout/OOM | Không gửi ảnh binary; chỉ gửi `imageRef` |

---

## 4. Giả định Producer

- Camera Stream là producer duy nhất cho các event `camera.motion.detected`, `camera.frame.analyzed`, `camera.status.changed`.
- Event chỉ chứa `imageRef` thay vì ảnh nhúng để giảm payload.
- `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `cameraId` là bắt buộc.
- Timestamps phải dùng ISO 8601 UTC.
- Provider có thể retry event; consumer phải xử lý idempotent.
- Nếu trạng thái camera thay đổi sang `offline` hoặc `error`, cần gửi `reason` và `lastSeen`.

---

## 5. Câu hỏi cho Consumer

1. Consumer cần trường nào bắt buộc trong `camera.motion.detected` để tính đúng motion count và abnormal detection?
2. `imageRef` có bắt buộc phải xuất hiện trong mọi event motion hay chỉ khi cần truy xuất frame?
3. `camera.status.changed` cần báo bao nhiêu chỉ số health metrics để dashboard đủ thông tin?
4. Consumer có cần guarantee ordering theo `occurredAt` hay chỉ cần idempotent và xử lý out-of-order?
5. Nếu event bị retry, consumer mong muốn thêm `attemptId` hay `retryCount` để hỗ trợ dedupe không?

---

## 6. Rủi ro tích hợp và đề xuất xử lý

| Rủi ro | Tác động | Đề xuất |
|---|---|---|
| Thay đổi eventType/topic | Consumer không nhận event | Chốt contract và duy trì backward compatibility |
| Thiếu `cameraId` | Event không gắn camera | Yêu cầu bắt buộc `cameraId` |
| Payload quá lớn do ảnh nhúng | Broker timeout / OOM | Chỉ gửi `imageRef` vào event |
| Timestamp không chuẩn | Event out-of-order | Chuẩn hoá ISO 8601 UTC |
| Retry duplicate | Consumer xử lý lặp | Dùng `eventId` và `correlationId` để dedupe |
| Status enum khác | Dashboard hiển thị sai | Thống nhất enum `online`, `offline`, `error`, `maintenance` |
