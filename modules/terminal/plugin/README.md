# Konsole native plugin

The only editable native plugin source is [app-decorations/konsole](../../../app-decorations/konsole/). The independent compiler syntax check copies that directory into the pinned upstream Konsole tree. Keep the real files there; no second implementation or source alias is needed. The terminal module owns its behavior, appearance and acceptance criteria.
