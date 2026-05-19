# Event Contract — Pair 07 Camera Stream → Analytics (Lab 02)

> Cặp Queue async: Camera Stream (Producer) gửi event cho Analytics (Consumer).
> Lab 02 ghi nhận event contract sơ bộ; Lab 03 sẽ tiếp tục đặc tả chi tiết bằng AsyncAPI.

## 1. Thông tin dependency

| Mục | Giá trị |
|---|---|
| Dependency số | 7 |
| Producer | Camera Stream |
| Consumer | Analytics |
| Cơ chế | Queue async |
| Event/Topic dự kiến | `camera.motion.detected`, `camera.frame.analyzed`, `camera.status.changed` |
| Message Broker | RabbitMQ / Kafka / Broker phù hợp |
| Người ghi | Nhóm 07 |
| Ngày cập nhật | 2026-05-19 |

## 2. Mục đích nghiệp vụ

**Mô tả chi tiết:**

- Producer (Camera Stream) publish event khi camera phát hiện motion, khi một frame đã được phân tích xong, hoặc khi trạng thái camera thay đổi.
- Consumer (Analytics) nhận event để cập nhật thống kê motion, tính toán object count, giám sát trạng thái camera, detect abnormal và cập nhật dashboard health.

## 3. Event name / Topic

| Mục | Giá trị |
|---|---|
| Producer | Camera Stream |
| Consumer | Analytics |
| Topic/event name | `camera.motion.detected`, `camera.frame.analyzed`, `camera.status.changed` |
| Delivery guarantee | At-least-once (consumer phải idempotent) |

### 3.1 Danh sách event/topic

| Event/Topic | Mô tả | Producer publish khi nào? | Consumer subscribe để làm gì? |
|---|---|---|---|
| `camera.motion.detected` | Camera phát hiện motion trong frame | Khi motion confidence vượt ngưỡng | Cập nhật thống kê motion, detect abnormal và trigger alert |
| `camera.frame.analyzed` | Frame đã được phân tích xong | Sau mỗi frame được xử lý xong | Cập nhật object count, processing health metrics |
| `camera.status.changed` | Trạng thái camera thay đổi | Khi camera online/offline/error hoặc health metrics thay đổi | Cập nhật dashboard trạng thái và cảnh báo |

---

## 4. Payload — Cấu trúc chung (Envelope)

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
| `correlationId` | UUID | ✓ | Dùng để trace luồng detection end-to-end |
| `source` | String | ✓ | Service gửi event, luôn là `camera-stream` |
| `data` | Object | ✓ | Payload chứa dữ liệu cụ thể của event |

---

### 4.1 Payload chi tiết theo event type

#### Event: `camera.motion.detected`

**Mục đích:** Analytics nhận để cập nhật thống kê motion, detect abnormal, và trigger alert.

```json
{
  "data": {
    "cameraId": "cam-01",
    "frameId": "frame-12345",
    "motionDetected": true,
    "motionConfidence": 0.92,
    "objectType": "person",
    "imageRef": "https://storage.campus.local/frames/frame-12345.jpg",
    "boundingBoxes": [
      { "x": 100, "y": 50, "width": 200, "height": 180 }
    ],
    "zone": "entrance",
    "location": "Building A"
  }
}
```

| Trường | Loại | Bắt buộc? | Mô tả |
|---|---|---|---|
| `cameraId` | String | ✓ | Định danh camera |
| `frameId` | String | ✓ | Định danh frame |
| `motionDetected` | Boolean | ✓ | `true` nếu phát hiện motion |
| `motionConfidence` | Number | ✓ | Độ tin cậy 0.0 ~ 1.0 |
| `objectType` | String | ✓ | Loại object: `person`, `vehicle`, `animal`, v.v. |
| `imageRef` | URL | ✗ | Link tới frame image trên storage, không gửi ảnh nhúng |
| `boundingBoxes` | Array | ✗ | Danh sách box `{ x, y, width, height }` |
| `zone` | String | ✗ | Zone/region trong camera |
| `location` | String | ✗ | Vị trí địa lý camera |

---

#### Event: `camera.frame.analyzed`

**Mục đích:** Analytics nhận để cập nhật object count và health metrics của frame processing.

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
| `detectedObjects` | Array | ✓ | Danh sách object `{ type, confidence }` |
| `analysisStatus` | String | ✓ | `completed`, `partial`, `failed` |
| `imageRef` | URL | ✗ | Link frame image |
| `processingTime` | Number | ✗ | Thời gian xử lý (ms) |
| `metadata` | Object | ✗ | Metadata model/version |

---

#### Event: `camera.status.changed`

**Mục đích:** Analytics nhận để giám sát camera online/offline và cập nhật health dashboard.

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
| `status` | String | ✓ | `online`, `offline`, `error`, `maintenance` |
| `reason` | String | ✓ | Lý do thay đổi |
| `lastSeen` | ISO 8601 | ✓ | Thời điểm cuối cùng camera active |
| `cpuUsage` | Number | ✗ | CPU % (0.0 ~ 100.0) |
| `memoryUsage` | Number | ✗ | Memory % (0.0 ~ 100.0) |
| `signalStrength` | Number | ✗ | Signal dBm |
| `healthMetrics` | Object | ✗ | Các metric bổ sung (uptime, frameRate, temperature) |

---

## 5. Ràng buộc cần thống nhất

| Vấn đề | Quyết định | Rationale |
|---|---|---|
| Event ID có bắt buộc? | ✓ **Có** | Để dedupe và trace |
| Có cần `correlationId`? | ✓ **Có** | Để trace luồng detection end-to-end |
| Retry event khi lỗi? | Consumer phải xử lý idempotent | Provider có thể retry, consumer dùng `eventId`/`correlationId` để dedupe |
| Timestamp format | ✓ **ISO 8601 UTC** | Đảm bảo consistent ordering |
| Ảnh binary nhúng? | ✗ **Không** | Tránh payload quá lớn, broker timeout |
| Broker/topic ordering | ⚠️ **Không đảm bảo** | Consumer xử lý out-of-order theo `occurredAt` |
| Dead-letter queue | ⚠️ **Chi tiết ở Lab 03** | Ghi note chính sách retry/DLQ vào Lab 03 |

---

## 6. Error case / Issue cần nghĩ trước

- Payload không đúng định dạng JSON hoặc thiếu field bắt buộc.
- Thiếu `cameraId` hoặc `eventType` khiến Analytics không thể định danh event.
- `occurredAt` sai định dạng hoặc không dùng UTC.
- Event duplicate do retry gây ra xử lý lặp.
- Provider và Consumer hiểu khác nhau về giá trị `status` của camera.
- Event quá lớn nếu gửi ảnh nhúng thay vì `imageRef`.

| Vấn đề | Hậu quả | Xử lý đề xuất |
|---|---|---|
| Payload không đúng JSON | Event bị reject / consumer không parse được | Log, DLQ, yêu cầu gửi lại |
| Thiếu `cameraId` | Không nhận biết camera | Bắt buộc `cameraId` trong contract |
| `occurredAt` sai định dạng | Thứ tự event sai | Quy định ISO 8601 UTC |
| Event duplicate do retry | Thống kê lặp | Dùng `eventId`/`correlationId` để dedupe |
| Gửi ảnh binary nhúng | Broker timeout, payload quá lớn | Chỉ gửi `imageRef` |
| `status` enum không đồng nhất | Dashboard sai | Validate enum, fallback `error` |
| Thiếu `correlationId` | Không trace end-to-end | Ghi warning và yêu cầu Provider cải thiện |

---

## 7. Câu hỏi gợi ý cho phiên đàm phán

| # | Câu hỏi | Vai trò | Ý nghĩa |
|---|---|---|---|
| 1 | Producer có gửi ảnh nhúng trong event không hay chỉ cung cấp `imageRef`? | Consumer | Xác định kích thước payload, tránh broker timeout |
| 2 | `camera.motion.detected` có luôn gồm `objectType` không? | Consumer | Xác định data cần thiết để phân loại abnormal event |
| 3 | `camera.status.changed` cần bao gồm bao nhiêu trường health metrics? | Consumer | Xác định đủ dữ liệu cho dashboard monitoring |
| 4 | `correlationId` dùng cho truy vết luồng end-to-end hay chỉ để dedupe? | Both | Xác định scope của correlation ID |
| 5 | Nếu Camera Stream retry event, Consumer cần thêm trường nào để dedupe tốt nhất? | Consumer | Xác định strategy idempotency tối ưu |
| 6 | Broker/topic có đảm bảo ordering event theo `occurredAt` không? | Both | Xác định cần xử lý out-of-order ở Consumer |
| 7 | Retry policy: bao lâu retry lần đầu, bao nhiêu lần total? | Both | Xác định SLA cho delivery guarantee |

---

## 8. Phạm vi Lab 02 vs Lab 03

| Aspect | Lab 02 (sơ bộ) | Lab 03 (chi tiết) |
|---|---|---|
| Event name/topic | ✓ Chốt trong Lab 02 | Không đổi |
| Payload structure | ✓ Thỏa thuận sơ bộ | ✓ AsyncAPI schema chi tiết |
| Retry/DLQ policy | ⚠️ Ghi note | ✓ Định nghĩa rõ |
| Topic schema validation | ⚠️ Sơ bộ | ✓ AsyncAPI + JSON Schema |
| Error handling details | ⚠️ Ghi chú | ✓ Mapping error code |
| Monitoring/metrics | ⚠️ Sơ bộ | ✓ SLA, metrics chi tiết |

---

## 9. Ghi chú hoàn thiện

- Lab 02: Cặp này ghi nhận **event contract sơ bộ** và ký kết qua `negotiation-log.md`.
- Lab 03: Tiếp tục đặc tả chi tiết AsyncAPI, topic schema, retry policy, monitoring metrics.
- Các issue cần chuyển sang Lab 03 xem trong section "Issue chuyển sang Lab 03".

## 10. Issue chuyển sang Lab 03

1. Mô tả AsyncAPI chi tiết cho các topic và message schema.
2. JSON Schema validation cho `data` payload.
3. Retry/backoff policy và policy DLQ.
4. Cơ chế lỗi, mã lỗi và mapping sự kiện thất bại.
5. SLA observability: latency, throughput, error rate, DLQ metrics.
6. Versioning strategy cho topic/schema.
7. Security/authentication cho producer và broker.
2. ...
3. ...
