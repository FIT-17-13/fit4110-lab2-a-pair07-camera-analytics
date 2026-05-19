# User Story — Camera Stream → Analytics

- **Cặp đàm phán:** pair-07
- **Dependency số:** 7
- **Product:** Smart Campus Operations Platform
- **Provider:** Camera Stream
- **Consumer:** Analytics
- **Cơ chế:** Queue async
- **Ngày cập nhật:** 2026-05-19

---

## 1. Cơ chế

**Queue async** — Producer (Camera Stream) publish event vào message broker, Consumer (Analytics) subscribe từ broker.

## 2. Bối cảnh kinh doanh

Camera Stream là dịch vụ producer. Nó publish các event camera vào broker để Analytics tiêu thụ.

Analytics dùng dữ liệu này để:

- Thống kê motion và abnormal event theo khu vực.
- Tính toán số lần camera phát hiện chuyển động.
- Giám sát tình trạng camera, online/offline và health.
- Cung cấp dữ liệu đầu vào cho dashboard và hệ thống cảnh báo.

## 3. Nhu cầu của Consumer (Analytics)

Analytics cần nhận event bất đồng bộ từ Camera Stream bao gồm:

| Yêu cầu | Chi tiết |
|---|---|
| Định danh event | `eventId` (uuid duy nhất), `eventType` (loại event), `correlationId` (truy vết luồng) |
| Thời gian | `occurredAt` (ISO 8601 UTC - khi event xảy ra), `source` (tên service gửi) |
| Thông tin camera | `cameraId` (định danh camera) |
| Dữ liệu chuyên biệt | Khác nhau tuỳ theo `eventType` (motion, frame analysis, status) |
| Idempotency | Consumer phải xử lý được duplicate event dựa trên `eventId` và `correlationId` |

**Trọng tâm Lab 02:** Analytics cần chốt được:
- Tên event/topic dự kiến
- Payload tối thiểu bắt buộc và bắt buộc (required vs optional fields)
- Quy tắc timestamp, enum values
- Cách xử lý duplicate và retry

## 4. Event trọng tâm

### 4.1 Danh sách event/topic

| Event/Topic | Mô tả | Producer publish khi nào? |
|---|---|---|
| `camera.motion.detected` | Camera phát hiện chuyển động trong frame | Khi motion confidence vượt ngưỡng |
| `camera.frame.analyzed` | Frame đã được phân tích xong, trả kết quả object detection | Sau mỗi frame được xử lý xong |
| `camera.status.changed` | Trạng thái camera thay đổi (online/offline/error) | Khi camera thay đổi trạng thái hoặc health metrics thay đổi |

### 4.2 Cấu trúc chung (Envelope)

Tất cả event tuân theo cấu trúc chung này:

```json
{
  "eventId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "eventType": "camera.motion.detected",
  "occurredAt": "2026-05-19T10:00:00Z",
  "correlationId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "source": "camera-stream",
  "data": { }
}
```

| Trường | Loại | Bắt buộc? | Mô tả |
|---|---|---|---|
| `eventId` | UUID | ✓ | Định danh duy nhất của event, dùng để dedupe |
| `eventType` | String | ✓ | Loại event: `camera.motion.detected`, `camera.frame.analyzed`, `camera.status.changed` |
| `occurredAt` | ISO 8601 | ✓ | Thời gian event xảy ra (UTC), format: `YYYY-MM-DDTHH:mm:ssZ` |
| `correlationId` | UUID | ✓ | Dùng để trace luồng detection end-to-end, xác định request gốc |
| `source` | String | ✓ | Service gửi event, luôn là `"camera-stream"` |
| `data` | Object | ✓ | Payload chứa dữ liệu cụ thể của event (khác nhau tuỳ `eventType`) |

### 4.3 Payload chi tiết theo event type

#### Event: `camera.motion.detected`

**Mục đích:** Analytics nhận để cập nhật thống kê motion, detect abnormal, và trigger alert

```json
{
  "data": {
    "cameraId": "cam-01",
    "frameId": "frame-12345",
    "motionDetected": true,
    "mQuy tắc và ràng buộc cần thống nhất

| Vấn đề | Quyết định | Rationale |
|---|---|---|
| Event ID có bắt buộc? | **Có** | Để dedupe và trace |
| Có cần `correlationId`? | **Có** | Để trace luồng detection end-to-end |
| Retry event khi lỗi? | Consumer phải xử lý idempotent | Provider có thể retry, Consumer dùng eventId/correlationId để dedupe |
| Timestamp format | **ISO 8601 UTC** (vd: `2026-05-19T10:00:00Z`) | Đảm bảo consistent ordering |
| Ảnh binary nhúng? | **Không, chỉ gửi `imageRef`** | Tránh payload quá lớn, broker timeout |
| `7. Câu hỏi gợi ý cho phiên đàm phán

| # | Câu hỏi | Vai trò | Ý nghĩa |
|---|---|---|---|
| 1 | Producer có gửi ảnh nhúng trong event không hay chỉ cung cấp `imageRef`? | Consumer | Xác định kích thước payload, tránh broker timeout |
| 2 | `camera.motion.detected` có luôn gồm `objectType` không? | Consumer | Xác định data cần thiết để phân loại abnormal event |
| 3 | `camera.status.changed` cần bao gồm bao nhiêu trường health metrics? | Consumer | Xác định đầy đủ dữ liệu cho dashboard monitoring |
| 4 | `correlationId` dùng cho truy vết luồng end-to-end hay chỉ để dedupe? | Consumer/Provider | Xác định scope của correlation ID trong hệ thống |
| 5 | Nếu Camera Stream retry event, Consumer cần thêm trường nào để dedupe tốt nhất? | Consumer | Xác định strategy idempotency tối ưu |
| 6 | Broker/topic có đảm bảo ordering của event theo `occurredAt` không? | Provider/Consumer | Xác định cần xử lý out-of-order ở Consumer |
| 7 | Retry policy: bao lâu retry lần đầu, bao nhiêu lần total? | Provider/Consumer | Xác định SLA cho delivery guarantee |

## 8. Phạm vi Lab 02 vs Lab 03

| Aspect | Lab 02 (sơ bộ) | Lab 03 (chi tiết) |
|---|---|---|
| Event name/topic | ✓ Chốt trong Lab 02 | Không đổi |
| Payload structure | ✓ Thỏa thuận sơ bộ | Chuyên sâu AsyncAPI schema |
| Retry/DLQ policy | ⚠️ Ghi note | ✓ Định nghĩa rõ |
| Topic schema validation | ⚠️ Sơ bộ | ✓ AsyncAPI + JSON Schema |
| Error handling details | ⚠️ Ghi chú | ✓ Mapping error code |
| Monitoring/metrics | ⚠️ Sơ bộ | ✓ SLA, metrics chi tiết |

---

## 9. Ghi chú hoàn thiện

- Lab 02: Cặp này ghi nhận **event contract sơ bộ** và ký kết qua `negotiation-log.md`
- Lab 03: Tiếp tục đặc tả chi tiết AsyncAPI, topic schema, retry policy, monitoring metrics
- Các issue cần chuyển sang Lab 03 xem trong `negotiation-log.md` section "Issue chuyển sang Lab 03"ent sai | Xác thực format trong contract, yêu cầu Provider chuẩn hoá |
| Event duplicate do retry | Thống kê motion/object count lặp | Consumer dùng `eventId`/`correlationId` để xác định duplicate, bỏ qua |
| Provider gửi ảnh binary nhúng | Payload quá nặng, broker timeout, OOM | Reject message, yêu cầu Provider gửi lại chỉ `imageRef` |
| Status enum value không xác định | Dashboard hiển thị sai | Consumer validate enum, fallback thành `"error"` |
| Event không có `correlationId` | Không trace được luồng gốc | Xử lý tạm thời, log warning để Provider cải thiện |
```

| Trường | Loại | Bắt buộc? | Mô tả |
|---|---|---|---|
| `cameraId` | String | ✓ | Định danh camera, vd `"cam-01"` |
| `frameId` | String | ✓ | Định danh frame trong stream |
| `motionDetected` | Boolean | ✓ | `true` nếu phát hiện chuyển động |
| `motionConfidence` | Number | ✓ | Độ tin cậy 0.0 ~ 1.0 |
| `objectType` | String | ✓ | Loại object: `"person"`, `"vehicle"`, `"animal"`, etc. |
| `imageRef` | URL | ✗ | Link tới frame image trên storage, không gửi ảnh nhúng |
| `boundingBoxes` | Array | ✗ | Danh sách box { x, y, width, height } cho mỗi object |
| `zone` | String | ✗ | Zone/region trong camera (vd: `"entrance"`, `"parking"`) |
| `location` | String | ✗ | Vị trí địa lý của camera |

---

#### Event: `camera.frame.analyzed`

**Mục đích:** Analytics nhận để cập nhật đếm object, health metrics của frame processing

```json
{
  "data": {
    "cameraId": "cam-01",
    "frameId": "frame-12345",
    "objectCount": 3,
    "detectedObjects": [
      { "type": "person", "confidence": 0.95 },
      { "type": "person", "confidence": 0.87 },
      { "type": "bicycle", "confidence": 0.72 }
    ],
    "analysisStatus": "completed",
    "imageRef": "https://storage.campus.local/frames/frame-12345.jpg",
    "processingTime": 145,
    "metadata": { "model": "yolov8", "version": "1.0" }
  }
}
```

| Trường | Loại | Bắt buộc? | Mô tả |
|---|---|---|---|
| `cameraId` | String | ✓ | Định danh camera |
| `frameId` | String | ✓ | Định danh frame |
| `objectCount` | Number | ✓ | Tổng số object phát hiện được |
| `detectedObjects` | Array | ✓ | Danh sách object: `{ type, confidence }` |
| `analysisStatus` | String | ✓ | `"completed"`, `"partial"`, `"failed"` |
| `imageRef` | URL | ✗ | Link frame image |
| `processingTime` | Number | ✗ | Thời gian xử lý (ms) |
| `metadata` | Object | ✗ | Metadata về model/version sử dụng |

---

#### Event: `camera.status.changed`

**Mục đích:** Analytics nhận để giám sát camera online/offline và cập nhật health dashboard

```json
{
  "data": {
    "cameraId": "cam-01",
    "status": "offline",
    "reason": "network_disconnect",
    "lastSeen": "2026-05-19T09:55:30Z",
    "cpuUsage": 45.2,
    "memoryUsage": 62.1,
    "signalStrength": -75,
    "healthMetrics": {
      "uptime": 864000,
      "frameRate": 0,
      "temperature": 52.5
    }
  }
}
```

| Trường | Loại | Bắt buộc? | Mô tả |
|---|---|---|---|
| `cameraId` | String | ✓ | Định danh camera |
| `status` | String | ✓ | `"online"`, `"offline"`, `"error"`, `"maintenance"` |
| `reason` | String | ✓ | Lý do thay đổi: `"power_off"`, `"network_disconnect"`, `"overheat"`, `"firmware_update"` |
| `lastSeen` | ISO 8601 | ✓ | Thời điểm cuối cùng camera active |
| `cpuUsage` | Number | ✗ | CPU % (0.0 ~ 100.0) |
| `memoryUsage` | Number | ✗ | Memory % (0.0 ~ 100.0) |
| `signalStrength` | Number | ✗ | Signal dBm (thường -100 ~ 0) |
| `healthMetrics` | Object | ✗ | Các metric bổ sung (uptime, frameRate, temperature) |

## 5. Error case / Issue cần nghĩ trước

- Payload không đúng định dạng JSON hoặc thiếu field bắt buộc.
- Thiếu `cameraId` hoặc `eventType` khiến Analytics không thể định danh event.
- `occurredAt` sai định dạng hoặc không dùng UTC.
- Event duplicate do retry gây ra xử lý lặp.
- Provider và Consumer hiểu khác nhau về giá trị `status` của camera.
- Event quá lớn nếu gửi ảnh nhúng thay vì `imageRef`.

## 6. Câu hỏi gợi ý cho phiên đàm phán

1. Producer có gửi ảnh nhúng trong event không hay chỉ cung cấp `imageRef`?
2. `camera.motion.detected` có cần `boundingBoxes` và `objectType` không?
3. `camera.status.changed` cần bao gồm trường health metrics nào để Analytics cập nhật dashboard?
4. `correlationId` dùng cho truy vết luồng end-to-end hay chỉ để dedupe nội bộ?
5. Nếu Camera Stream retry event, consumer cần trường bổ sung nào để đảm bảo idempotent?

## 7. Ghi chú phạm vi Lab 02

- Đây là cặp Queue async nên Lab 02 chỉ cần ghi nhận thỏa thuận sơ bộ về event name, topic và payload.
- Đặc tả chi tiết AsyncAPI/topic schema sẽ tiếp tục ở Lab 03.
- Nếu giảng viên yêu cầu, có thể bổ sung thỏa thuận vào `negotiation-log.md` hoặc `docs/event-contract-template.md`.
