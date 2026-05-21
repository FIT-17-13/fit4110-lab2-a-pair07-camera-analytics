# Bien ban dam phan hop dong API

- Cap dam phan: pair-07 Camera Stream -> Analytics
- Product: Smart Campus Operations Platform
- Provider: Camera Stream
- Consumer: Analytics
- Co che: Queue async, mo phong bang OpenAPI/Prism trong Lab 02
- Phien: v1.0.0
- Ngay: 2026-05-19

---

## Issue #1 - Event envelope bat buoc

- Raised by: Consumer
- Scope: Tat ca camera events
- Concern: Analytics can dinh danh, trace va dedupe event on dinh.
- Proposal: Tat ca event phai co `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `data`.
- Resolution: Accepted.
- Rationale: Day la envelope toi thieu cho async integration va observability.
- Impact: Provider phai sinh UUID cho `eventId` va `correlationId`; Consumer reject payload thieu field bat buoc.

---

## Issue #2 - Topic/eventType duoc ho tro

- Raised by: Provider
- Scope: Event taxonomy
- Concern: Neu topic qua rong, Provider kho dam bao schema on dinh.
- Proposal: v1.0 chi ho tro `camera.motion.detected`, `camera.frame.analyzed`, `camera.status.changed`.
- Resolution: Accepted.
- Rationale: Ba event nay dap ung nhu cau motion, object count va camera health cua Analytics.
- Impact: Event ngoai enum se bi xem la invalid trong contract v1.0.

---

## Issue #3 - Anh trong payload

- Raised by: Provider
- Scope: `camera.motion.detected`, `camera.frame.analyzed`
- Concern: Gui anh binary lam payload lon, de gay broker timeout.
- Proposal: Khong gui binary image; chi gui `imageRef` dang URI. `imageRef` bat buoc voi motion event va optional voi frame analyzed.
- Resolution: Accepted.
- Rationale: Giu event nhe, Analytics van co link de dieu tra khi can.
- Impact: Provider phai upload frame vao storage truoc khi publish motion event.

---

## Issue #4 - Motion confidence va bounding boxes

- Raised by: Consumer
- Scope: `camera.motion.detected`
- Concern: Analytics can confidence de tinh abnormal, nhung bounding boxes khong phai luc nao cung co.
- Proposal: `motionConfidence` bat buoc, `boundingBoxes` optional.
- Resolution: Accepted.
- Rationale: Confidence la metric chinh; bounding boxes phu thuoc model va co the bo sung sau.
- Impact: Consumer khong duoc fail khi `boundingBoxes` vang mat hoac la mang rong.

---

## Issue #5 - Status enum va reason

- Raised by: Consumer
- Scope: `camera.status.changed`
- Concern: Dashboard se hien thi sai neu Provider gui status tuy y.
- Proposal: `status` chi gom `online`, `offline`, `error`, `maintenance`; `reason` dung enum da chot trong OpenAPI.
- Resolution: Accepted.
- Rationale: Enum ro rang giup Analytics validate va gom nhom canh bao.
- Impact: Provider phai map trang thai noi bo sang enum contract truoc khi publish.

---

## Issue #6 - Idempotency va retry

- Raised by: Consumer
- Scope: Tat ca camera events
- Concern: Delivery at-least-once co the tao duplicate va lam sai thong ke.
- Proposal: Provider giu nguyen `eventId` khi retry cung mot event. Consumer dedupe theo `eventId`; `correlationId` dung de trace.
- Resolution: Accepted.
- Rationale: Idempotency la bat buoc voi queue async.
- Impact: Provider khong tao eventId moi cho retry; Consumer luu danh sach eventId da xu ly.

---

## Issue #7 - Timestamp va ordering

- Raised by: Consumer
- Scope: Tat ca camera events
- Concern: Event co the den khong dung thu tu arrival time.
- Proposal: `occurredAt` bat buoc theo ISO 8601 UTC; Analytics sap xep theo `occurredAt`.
- Resolution: Accepted.
- Rationale: Ordering dua vao thoi diem xay ra, khong dua vao thoi diem consume.
- Impact: Provider chuan hoa timestamp UTC; Consumer xu ly out-of-order trong read model.

---

## Issue #8 - Pham vi Lab 02 va Lab 03

- Raised by: Provider/Consumer
- Scope: Contract artefacts
- Concern: Pair-07 la queue async nhung Lab 02 yeu cau OpenAPI va Prism mock.
- Proposal: Lab 02 dung OpenAPI de mo phong event contract qua `POST /camera-events`; Lab 03 se viet AsyncAPI/topic schema chi tiet.
- Resolution: Accepted.
- Rationale: Vua dap ung rubric Lab 02, vua khong lam sai ban chat async integration.
- Impact: `openapi.yaml` co cac endpoint mock/read model; ghi chu AsyncAPI duoc chuyen sang Lab 03.

---

## Chot hop dong v1.0.0

Provider sign-off: Camera Stream team  
Consumer sign-off: Analytics team  
Witness (GV/TA):  
Date: 2026-05-19

---

## Warning / viec chuyen sang Lab 03

| Muc | Ly do | Ke hoach |
|---|---|---|
| AsyncAPI chua day du | Lab 02 tap trung OpenAPI 3.1 va Prism mock | Viet AsyncAPI cho topic, retry, DLQ trong Lab 03 |
| Retry interval chua chi tiet | Lab 02 chi chot idempotency va max retry mock | Bo sung backoff policy trong Lab 03 |
| Broker ordering chua cam ket | Can phu thuoc broker that | Consumer xu ly out-of-order bang `occurredAt` |
