# Versioning

Contract hien tai: `1.0.0`

## Chien luoc version

Hop dong Camera Stream -> Analytics dung Semantic Versioning:

- MAJOR: thay doi pha vo tuong thich, vi du doi ten `eventType`, xoa field bat buoc, doi kieu du lieu.
- MINOR: them eventType moi, them field optional, them endpoint read-only khong pha vo consumer hien tai.
- PATCH: sua mo ta, example, typo, rang buoc ro hon nhung khong doi hanh vi.

## Quy tac tuong thich

- Khong doi gia tri `eventType` trong v1.x.
- Khong xoa cac field bat buoc trong envelope: `eventId`, `eventType`, `occurredAt`, `correlationId`, `source`, `data`.
- Field moi trong v1.x phai la optional hoac co default ro rang.
- Consumer phai bo qua field unknown neu broker/schema validation cho phep.
- Provider phai giu `eventId` on dinh khi retry cung mot event.

## Lich su phien ban

| Version | Ngay | Thay doi |
|---|---|---|
| 1.0.0 | 2026-05-19 | Chot contract Lab 02 cho `camera.motion.detected`, `camera.frame.analyzed`, `camera.status.changed`; them Problem Details va mock endpoints. |

## Deprecation policy

- Field/eventType can bo se duoc danh dau deprecated it nhat mot MINOR version truoc khi xoa.
- Consumer va Provider phai cap nhat `negotiation-log.md` khi co thay doi lon.
- Breaking change chi duoc thuc hien trong MAJOR version moi, vi du `2.0.0`.
