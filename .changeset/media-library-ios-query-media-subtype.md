---
'expo-media-library': patch
---

[iOS] Add `AssetField.MEDIA_SUBTYPE` so a `Query` can filter assets by `MediaSubtype`, for example screenshots or Live Photos. `eq` matches assets that have the subtype, `within` matches assets that have any of the given subtypes.
