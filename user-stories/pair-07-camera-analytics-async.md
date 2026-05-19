# User Story — Camera Stream → Analytics

## 1. Cơ chế

**Queue async**

## 2. Bối cảnh

Camera Stream publish các event camera cho Analytics. Analytics dùng dữ liệu này để:

- Thống kê motion và abnormal event theo khu vực.
- Tính toán số lần camera phát hiện chuyển động.
- Giám sát tình trạng camera, online/offline và health.
- Cung cấp dữ liệu đầu vào cho dashboard và hệ thống cảnh báo.

## 3. Nhu cầu của Consumer

Analytics cần nhận event bất đồng bộ từ Camera Stream, bao gồm thông tin camera, thời điểm, loại event và các dữ liệu liên quan để xử lý thống kê.

Trong Lab 02, phần quan trọng là đồng ý:

- Tên event chính.
- Payload tối thiểu.
- `eventId`, `eventType`, `occurredAt`, `correlationId`.
- Các trường bắt buộc để Analytics có thể làm idempotent và trace.

## 4. Endpoint / Event trọng tâm

- `Event camera.motion.detected`
- `Event camera.frame.analyzed`
- `Event camera.status.changed`

### Payload tối thiểu đề xuất

```json
{
  "eventId": "uuid",
  "eventType": "camera.motion.detected",
  "occurredAt": "2026-05-19T10:00:00Z",
  "correlationId": "uuid",
  "source": "camera-stream",
  "data": {
    "cameraId": "cam-01",
    "frameId": "frame-123",
    "motionDetected": true,
    "motionConfidence": 0.93,
    "objectType": "person",
    "imageRef": "https://.../frame-123.jpg"
  }
}
```

### Các event cụ thể

- `camera.motion.detected`
  - data cần: `cameraId`, `frameId`, `motionDetected`, `motionConfidence`, `imageRef`
- `camera.frame.analyzed`
  - data cần: `cameraId`, `frameId`, `objectCount`, `detectedObjects`, `analysisStatus`
- `camera.status.changed`
  - data cần: `cameraId`, `status`, `reason`, `lastSeen`, `healthMetrics`

## 5. Error case / Issue cần nghĩ trước

- Payload không đúng định dạng JSON hoặc thiếu trường bắt buộc.
- Thiếu `cameraId` hoặc `eventType` khiến Analytics không thể liên kết.
- `occurredAt` sai định dạng hoặc timezone không đồng nhất.
- Event trùng lặp retry gây xử lý lặp.
- Provider và Consumer hiểu khác nhau về giá trị trạng thái camera.
- Event quá lớn nếu gửi ảnh nhúng thay vì `imageRef`.

## 6. Câu hỏi gợi ý cho phiên đàm phán

1. Có gửi ảnh thật vào event không hay chỉ gửi `imageRef`?
2. Motion event có cần `confidence`, `boundingBoxes`, `objectType` không?
3. `camera.status.changed` cần báo `offlineReason` và các chỉ số health cụ thể nào?
4. `correlationId` sẽ dùng cho luồng phát hiện chuyển động hay chỉ dùng cho tracing?
5. Producer có giữ ordering theo `occurredAt` không?

## 7. Ghi chú phạm vi Lab 02

Cặp này thuộc Queue async. Trong Lab 02, hai bên chưa cần viết AsyncAPI đầy đủ. Chỉ cần ghi rõ thỏa thuận sơ bộ về event name, payload và các trường bắt buộc, rồi chuyển sang Lab 03 để đặc tả AsyncAPI/topic schema.

> Nếu giảng viên yêu cầu, ghi thêm thỏa thuận sơ bộ vào `negotiation-log.md` hoặc dùng `docs/event-contract-template.md`.
