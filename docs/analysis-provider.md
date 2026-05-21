# Phan tich yeu cau - vai Provider

- Cap dam phan: pair-07 Camera Stream -> Analytics
- Product: Smart Campus Operations Platform
- Provider service: Camera Stream
- Consumer service: Analytics
- Co che: Queue async, mo phong bang OpenAPI/Prism trong Lab 02
- Ngay: 2026-05-19

---

## 1. Tai nguyen / event Provider phat ra

| Resource | Mo ta | Truong bat buoc | Truong tuy chon |
|---|---|---|---|
| `camera.motion.detected` | Event khi camera phat hien chuyen dong | `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `data.cameraId`, `data.frameId`, `data.motionDetected`, `data.motionConfidence`, `data.imageRef` | `objectType`, `boundingBoxes`, `zone`, `location` |
| `camera.frame.analyzed` | Event khi frame da duoc phan tich xong | `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `data.cameraId`, `data.frameId`, `data.objectCount`, `data.detectedObjects`, `data.analysisStatus` | `imageRef`, `processingTimeMs`, `model` |
| `camera.status.changed` | Event khi trang thai camera thay doi | `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `data.cameraId`, `data.status`, `data.reason`, `data.lastSeen` | `cpuUsage`, `memoryUsage`, `signalStrength`, `healthMetrics` |

---

## 2. Hinh thuc publish event

| Method | Topic / EventType | Muc dich | Khi nao publish |
|---|---|---|---|
| PUBLISH | `camera.motion.detected` | Gui motion event cho Analytics thong ke va phat hien abnormal | Khi `motionConfidence` vuot nguong |
| PUBLISH | `camera.frame.analyzed` | Gui ket qua object detection cua frame | Khi xu ly frame hoan tat hoac co ket qua partial |
| PUBLISH | `camera.status.changed` | Gui trang thai online/offline/error/maintenance | Khi status hoac health metrics thay doi |

Trong Lab 02, queue async duoc mo phong bang endpoint `POST /camera-events` de co the lint, mock va test bang `curl`.

---

## 3. Error case Provider can du doan

| Tinh huong | Hieu ung | Xu ly du kien |
|---|---|---|
| Payload thieu field bat buoc | Analytics reject hoac dua vao DLQ | Validate schema truoc khi publish |
| `eventType` khong dung enum | Consumer khong map duoc payload | Chi publish 3 eventType da chot |
| `occurredAt` khong phai ISO 8601 UTC | Analytics sap xep sai thoi gian | Chuan hoa timestamp truoc publish |
| Retry tao duplicate event | Thong ke bi dem lap neu consumer khong dedupe | Giu nguyen `eventId` khi retry cung mot event |
| Gui anh binary trong payload | Payload lon, broker timeout | Chi gui `imageRef` dang URI |
| Status/reason khong nam trong enum | Dashboard hien thi sai | Map ve enum da thoa thuan, neu khong ro dung `unknown` |

---

## 4. Gia dinh Provider

- Camera Stream la producer duy nhat cua 3 topic trong contract v1.0.
- `source` luon co gia tri `camera-stream`.
- `eventId` la UUID duy nhat cho moi event logic; retry khong duoc tao `eventId` moi.
- `correlationId` duoc dung de trace luong detection end-to-end.
- Provider su dung delivery mode at-least-once, nen Analytics phai idempotent.
- Provider khong publish anh binary; payload chi chua `imageRef`.

---

## 5. Cau hoi cho Consumer

1. Analytics co can `imageRef` bat buoc trong `camera.motion.detected` de dieu tra abnormal khong?
2. `boundingBoxes` co bat buoc trong motion event hay chi gui khi model tra ve du lieu?
3. Consumer can nhung metric nao trong `camera.status.changed` de dashboard du thong tin?
4. Consumer xu ly out-of-order event theo `occurredAt` nhu the nao?
5. Khi nhan duplicate, Consumer uu tien dedupe theo `eventId` hay ket hop `eventId` va `correlationId`?

---

## 6. Rui ro tich hop va de xuat

| Rui ro | Tac dong | De xuat |
|---|---|---|
| Doi topic/eventType | Consumer khong nhan hoac parse sai | Khong doi enum trong v1.x; neu can doi thi tao version moi |
| Thieu `cameraId` | Khong gan duoc event vao camera | Bat buoc trong moi payload `data` |
| Payload qua lon | Broker timeout, ton bo nho | Chi dung URI `imageRef` |
| Timestamp khong chuan | Bao cao sai thu tu su kien | ISO 8601 UTC bat buoc |
| Duplicate do retry | Thong ke sai | Dedupe bang `eventId` va giu stable khi retry |
| Status enum khac nhau | Dashboard sai | Dung enum `online`, `offline`, `error`, `maintenance` |
