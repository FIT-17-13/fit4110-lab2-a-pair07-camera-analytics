# Phan tich yeu cau - vai Consumer

- Cap dam phan: pair-07 Camera Stream -> Analytics
- Product: Smart Campus Operations Platform
- Consumer service: Analytics
- Provider service: Camera Stream
- Co che: Queue async, mo phong bang OpenAPI/Prism trong Lab 02
- Ngay: 2026-05-19

---

## 1. Tai nguyen Consumer can nhan

| Resource | Consumer dung de lam gi | Truong bat buoc | Truong tuy chon |
|---|---|---|---|
| `camera.motion.detected` | Cap nhat motion count, phat hien abnormal, trigger canh bao | `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `data.cameraId`, `data.frameId`, `data.motionDetected`, `data.motionConfidence`, `data.imageRef` | `objectType`, `boundingBoxes`, `zone`, `location` |
| `camera.frame.analyzed` | Cap nhat object count va ket qua model | `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `data.cameraId`, `data.frameId`, `data.objectCount`, `data.detectedObjects`, `data.analysisStatus` | `imageRef`, `processingTimeMs`, `model` |
| `camera.status.changed` | Giam sat camera online/offline/error va cap nhat dashboard | `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `data.cameraId`, `data.status`, `data.reason`, `data.lastSeen` | `cpuUsage`, `memoryUsage`, `signalStrength`, `healthMetrics` |

---

## 2. Hinh thuc nhan event

Analytics khong goi truc tiep Camera Stream bang REST trong production. Analytics subscribe cac topic tu broker theo co che queue async. Trong Lab 02, endpoint `POST /camera-events` chi dung de mo phong payload va tao bang chung mock.

| Muc tieu | Topic / EventType | Ky vong xu ly |
|---|---|---|
| Motion detected | `camera.motion.detected` | Dedupe theo `eventId`, cap nhat thong ke motion, danh gia abnormal |
| Frame analyzed | `camera.frame.analyzed` | Luu object count, detected objects va processing metadata |
| Status changed | `camera.status.changed` | Cap nhat trang thai camera, canh bao neu `offline` hoac `error` |

---

## 3. Error case Consumer can xu ly

| Van de | Consumer hieu la gi | Xu ly |
|---|---|---|
| Payload khong dung JSON/schema | Event malformed | Reject, log loi, dua vao DLQ/quarantine |
| Thieu `cameraId` hoac `eventType` | Khong xac dinh nguon hoac loai event | Khong xu ly nghiep vu, bao loi cho Provider |
| `occurredAt` sai dinh dang | Khong sap xep duoc timeline | Reject hoac quarantine, yeu cau Provider chuan hoa UTC |
| Duplicate event do retry | Co the dem lap motion/object | Bo qua neu `eventId` da xu ly |
| Thieu `correlationId` | Kho trace luong end-to-end | Reject theo contract v1.0 vi day la field bat buoc |
| Status/reason ngoai enum | Dashboard sai | Reject schema hoac map vao canh bao tich hop |

---

## 4. Gia dinh Consumer

- Analytics xu ly delivery mode at-least-once va phai idempotent.
- `eventId` la khoa dedupe chinh; `correlationId` dung cho trace va gom nhom luong.
- Event co the den out-of-order, Analytics sap xep theo `occurredAt`.
- Payload khong chua anh binary; Analytics chi doc `imageRef` khi can dieu tra frame.
- `imageRef` bat buoc trong `camera.motion.detected`, nhung optional trong `camera.frame.analyzed`.
- Lab 03 se dac ta chi tiet AsyncAPI, retry, DLQ va monitoring.

---

## 5. Cau hoi cho Provider

1. Provider co cam ket khong doi topic/eventType trong v1.x khong?
2. `camera.motion.detected` co luon co `imageRef` khong?
3. `boundingBoxes` va `objectType` co the vang mat trong case motion confidence thap khong?
4. `camera.status.changed` se publish theo heartbeat hay chi khi status thay doi?
5. Retry policy cua Provider la bao nhieu lan va khoang cach retry nhu the nao?

---

## 6. Rui ro tich hop va de xuat

| Rui ro | Tac dong | De xuat |
|---|---|---|
| Provider doi field/topic | Consumer parse sai | Versioning ro trong `VERSIONING.md` |
| Payload thieu field bat buoc | Analytics mat du lieu | Schema validation truoc khi xu ly |
| Duplicate do retry | Thong ke sai | Dedupe bang `eventId` |
| Out-of-order event | Timeline sai | Sap xep theo `occurredAt`, khong dua vao arrival time |
| Anh binary trong payload | Qua tai broker | Chi chap nhan URI `imageRef` |
| Enum status khong thong nhat | Dashboard sai | Dung enum da chot trong OpenAPI |
