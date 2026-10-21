# Simple GLP Play assets

- `metadata/android/en-US/`: original Android listing. Localized listing text
  for all 50 Play locales now lives in `android/play-assets/metadata/android/`.
- `icon-512.png`: RGB512 icon derived from the existing iOS app icon.
- `../scripts/play-products.py`: offline plan by default, US7.99/31.99/71.99,
  seven-day new-subscriber trials and the fleet PPP curve; no API writes without
  `--apply`.

`feature-graphic.svg` is the editable source for the rendered RGB 1024x500
feature graphic. `screenshots/`: four real captures from
`project-docs/android/screenshots`, center-cropped from 1080x2400 to 1080x2160
(status and gesture bars trimmed) to meet Play's 2:1 limit.
Android policies are under `docs/android/`.
