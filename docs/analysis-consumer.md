# Phân tích yêu cầu — vai Consumer

- Cặp đàm phán: pair-07 Camera Stream → Analytics
- Product: Smart Campus
- Consumer service: Analytics
- Provider service: Camera Stream
- Người viết: Nhóm 07
- Ngày: 2026-05-19

---

## 1. Resource Consumer cần nhận/gửi

| Resource | Consumer dùng để làm gì? | Field bắt buộc với Consumer | Field có thể tùy chọn |
|---|---|---|---|
| Camera event | Nhận event camera để cập nhật thống kê, detect abnormal và giám sát camera | eventId, eventType, occurredAt, source, cameraId, data | imageRef, metadata, location |
| Motion detection event | Tính toán số motion, phát hiện bất thường và trigger cảnh báo | motionDetected, motionConfidence, frameId | objectType, boundingBoxes, zone |
| Camera status event | Giám sát trạng thái camera, offline/online, health | status, reason, lastSeen | cpuUsage, memoryUsage, signalStrength |

---

## 2. API Consumer cần gọi

Cặp này dùng Queue async, Analytics không gọi REST trực tiếp với Camera Stream. Thay vào đó, Analytics subscribe/consume các event từ broker.

| Method | Path / Topic | Lúc nào nhận? | Kỳ vọng xử lý |
|---|---|---|---|
| SUBSCRIBE | `camera.events.motion` | Khi Camera Stream publish motion event | Nhận payload, cập nhật thống kê motion, kiểm tra abnormal |
| SUBSCRIBE | `camera.events.frame` | Khi frame đã phân tích xong | Nhận kết quả frame analysis để tính object count và health metrics |
| SUBSCRIBE | `camera.events.status` | Khi camera thay đổi trạng thái | Nhận trạng thái camera để cập nhật dashboard và cảnh báo offline |

---

## 3. Error case Consumer cần xử lý

Tối thiểu 5 case.

| Vấn đề | Consumer hiểu là gì? | Consumer sẽ xử lý thế nào? |
|---|---|---|
| Payload không đúng JSON hoặc thiếu trường bắt buộc | Event malformed | Log lỗi, chuyển vào dead-letter/quarantine, không cập nhật |
| Thiếu `cameraId` hoặc `eventType` | Không thể xác định nguồn event | Bỏ qua, báo sự cố cho Provider |
| Dữ liệu `occurredAt` sai định dạng | Không xác định thứ tự event đúng | Log và yêu cầu Provider chuẩn hoá ISO 8601 UTC |
| Event trùng lặp / retry | Có thể xử lý lặp | Dùng `eventId`/`correlationId` để idempotent |
| Event không có `correlationId` | Không theo dõi đúng luồng detection | Ghi cảnh báo và xử lý tạm thời theo `cameraId` và timestamp |
| Status event sai giá trị | Trạng thái hiển thị sai dashboard | Xác thực giá trị trước khi cập nhật, fallback thành `unknown` |

---

## 4. Giả định bổ sung

- Camera Stream publish event lên broker theo topic dự kiến và giữ event name ổn định.
- Payload chỉ truyền `imageRef` hoặc metadata, không gửi ảnh binary trực tiếp.
- `eventId` và `correlationId` là bắt buộc để consumer idempotent và trace flow.
- Tất cả timestamps dùng UTC ISO 8601.
- Consumer chịu trách nhiệm xử lý duplicate và out-of-order event bằng timestamp.
- Nếu provider retry event, consumer vẫn phải tránh xử lý lặp.

---

## 5. Câu hỏi cho Provider

1. Event `camera.motion.detected` có cần gửi `confidence` và `boundingBoxes` không?
2. Có gửi ảnh thô trong event không hay chỉ gửi `imageRef`? Nếu không gửi ảnh, `imageRef` có luôn tồn tại?
3. Sự kiện `camera.status.changed` cần bao gồm những trường health metrics nào (offlineReason, cpuUsage, signalStrength)?
4. `correlationId` được dùng cho luồng detection cụ thể hay chỉ cho troubleshooting?
5. Producer có đảm bảo ordering theo `occurredAt` không?

---

## 6. Rủi ro tích hợp

| Rủi ro | Tác động | Đề xuất xử lý |
|---|---|---|
| Provider đổi tên field hoặc eventType | Consumer parse sai payload | Chốt naming và mapping trong event contract |
| Provider gửi payload quá lớn | Consumer/queue timeout hoặc OOM | Thống nhất chỉ gửi `imageRef`, không gửi binary |
| Event duplicate do retry | Thống kê sai, cảnh báo lặp | Xây idempotent theo `eventId`/`correlationId` |
| Provider thiếu `cameraId` | Không liên kết được event với camera | Bắt buộc `cameraId` trong contract |
| Timestamp không chuẩn | Xử lý thứ tự sai | Quy định ISO 8601 UTC |

