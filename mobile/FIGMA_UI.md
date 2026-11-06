# μToken Mobile UI – Figma implementation

## Scope

20 main M/O Figma frames are implemented for Light and Dark at 390 × 844. The Figma canvas contains 24 frames total; S01–S04 are separate state-only designs and excluded from this UI assignment.

The original Figma file was accessed in read-only mode. No Figma layers or styles were modified.

## Source of truth

- lib/core/mock/data/figma_light_01.json through figma_light_10.json: original Light layers.
- lib/core/mock/data/figma_dark_01.json through figma_dark_10.json: original Dark layers.
- lib/core/mock/data/figma_proto_hotspots.json: clickable prototype regions.
- lib/core/mock/data/figma_navigation_targets.json: navigation targets.
- assets/figma/*.svg: original exported vector layers and provider icons.
- assets/fonts/: Be Vietnam Pro font (including its OFL license).

The FigmaMockRepository loads presentation fixtures. The FigmaPixelScreen widget renders source layers without hard-coding sample numbers, labels, text, colors, or images in the widget implementation.

## Local development

To preview the UI without Firebase credentials, run flutter pub get, then flutter run -t lib/main_ui_preview.dart.

To verify, run flutter analyze and flutter test.

The real app entrypoint requires team-provided Firebase configuration. Prototype navigation is available, while actual Google sign-in, syncing, export, deletion, budget saving and AI API calls belong to their respective backend features; UI tap targets do not fake those operations.

## Included frames

M01, M02, M03, M04, M04B, M05, M05B, M05C, M06, M07, M09, M10, M11, M12, M13, M14, M15, O01, O02, O03.

S01, S02, S03 and S04 are intentionally excluded.
