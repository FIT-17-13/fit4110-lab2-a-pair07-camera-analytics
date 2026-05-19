# Phân tích yêu cầu — vai Consumer

- Cặp đàm phán: pair-07 Camera Stream → Analytics
- Product: Smart Campus
- Consumer service: Analytics
- Provider service: Camera Stream
- Người viết: Nhóm 07
- Ngày: 2026-05-19

---

## 1. Tài nguyên Consumer cần nhận

| Resource | Consumer dùng để làm gì? | Trường bắt buộc | Trường tùy chọn |
|---|---|---|---|
| `camera.motion.detected` | Cập nhật thống kê motion, phát hiện abnormal, trigger cảnh báo | `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `cameraId`, `frameId`, `motionDetected`, `motionConfidence` | `objectType`, `imageRef`, `boundingBoxes`, `zone`, `location` |
| `camera.frame.analyzed` | Cập nhật object count, health metrics của frame processing | `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `cameraId`, `frameId`, `objectCount`, `detectedObjects`, `analysisStatus` | `imageRef`, `processingTime`, `metadata` |
| `camera.status.changed` | Giám sát camera online/offline/error, cập nhật health dashboard | `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `cameraId`, `status`, `reason`, `lastSeen` | `cpuUsage`, `memoryUsage`, `signalStrength`, `healthMetrics` |

---

## 2. Hình thức nhận event

Analytics không gọi REST trực tiếp với Camera Stream. Thay vào đó, Analytics subscribe/consume các event từ broker theo cơ chế Queue async.

| Mục tiêu | Topic / EventType | Kịch bản nhận | Kỳ vọng xử lý |
|---|---|---|---|
| Motion detected | `camera.motion.detected` | Khi Camera Stream phát hiện motion confidence vượt ngưỡng | Cập nhật thống kê, đánh giá abnormal, lưu `eventId` để dedupe |
| Frame analyzed | `camera.frame.analyzed` | Khi frame được phân tích xong | Cập nhật object count, health metrics, lưu kết quả phân tích |
| Status changed | `camera.status.changed` | Khi camera status hoặc health metrics thay đổi | Cập nhật dashboard trạng thái và cảnh báo nếu `offline`/`error` |

---

## 3. Error case Consumer cần xử lý

| Vấn đề | Consumer hiểu là gì? | Consumer sẽ xử lý |
|---|---|---|
| Payload không đúng JSON hoặc thiếu trường bắt buộc | Event malformed / invalid | Log lỗi, chuyển vào DLQ/quarantine, không xử lý |
| Thiếu `cameraId` hoặc `eventType` | Không xác định nguồn event | Bỏ qua event, báo lỗi cho Provider |
| `occurredAt` sai định dạng hoặc không phải UTC | Không xác định thứ tự event đúng | Log cảnh báo, yêu cầu Provider chuẩn hoá ISO 8601 UTC |
| Event duplicate / retry | Trùng lặp event do At-least-once | Dùng `eventId` và `correlationId` để dedupe, bỏ qua event đã xử lý |
| Thiếu `correlationId` | Không trace được luồng xử lý end-to-end | Ghi cảnh báo, dùng `cameraId` và `occurredAt` tạm thời để phân tích |
| Giá trị `status` không hợp lệ | Dashboard hiển thị sai trạng thái | Validate enum, fallback thành `error` hoặc `unknown` |

---

## 4. Giả định Consumer

- Camera Stream là Producer duy nhất cho cặp này.
- Event chỉ gửi `imageRef`; không gửi ảnh binary trực tiếp.
- `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `cameraId` là bắt buộc.
- Timestamps phải dùng ISO 8601 UTC: `YYYY-MM-DDTHH:mm:ssZ`.
- Consumer chịu trách nhiệm xử lý duplicate và out-of-order event.
- Nếu Provider retry event, consumer vẫn phải idempotent.

---

## 5. Câu hỏi cho Provider

1. Event `camera.motion.detected` có cần gửi `boundingBoxes` và `objectType` trong tất cả case không?
2. Producer có gửi ảnh nhúng trong event không hay chỉ cung cấp `imageRef`?
3. `camera.status.changed` cần bao gồm trường `healthMetrics` nào để dashboard giám sát đủ? (`cpuUsage`, `memoryUsage`, `signalStrength`, `temperature`)
4. `correlationId` dùng để trace end-to-end hay chỉ để dedupe nội bộ?
5. Broker có đảm bảo ordering theo `occurredAt` không?

---

## 6. Rủi ro tích hợp và đề xuất xử lý

| Rủi ro | Tác động | Đề xuất |
|---|---|---|
| Provider đổi tên field hoặc eventType | Consumer parse sai payload | Chốt event contract và kiểm tra schema khi deploy |
| Payload quá lớn do ảnh nhúng | Broker timeout / OOM | Chỉ dùng `imageRef`, không gửi ảnh binary |
| Event duplicate do retry | Thống kê motion/object count sai | Xây idempotent theo `eventId`/`correlationId` |
| Thiếu `cameraId` | Không xác định camera | Yêu cầu `cameraId` là bắt buộc |
| Timestamp không theo UTC | SAI thứ tự event | Chuẩn hoá ISO 8601 UTC |
| Trạng thái không cùng enum | Dashboard hiển thị sai | Thống nhất enum `online`, `offline`, `error`, `maintenance` |

