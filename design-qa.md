# Healthy Habits Game Tabs — Design QA

## Evidence

- Source visual truth: `/Users/haydenberio/.codex/generated_images/01a0d02e-b125-7681-8c8f-8c2617342f98/exec-3ab8c697-1f06-4de9-bf83-06e1ae5e6526.png`
- Focus implementation: `/var/folders/n_/2sx0gh8s7bxfb6523wjcp3wh0000gn/T/screenshot_optimized_3c576c16-c21c-4db5-a4be-77d97c434671.jpg`
- Quick implementation: `/var/folders/n_/2sx0gh8s7bxfb6523wjcp3wh0000gn/T/screenshot_optimized_5baeb519-946a-4f06-a995-c8d6b594b709.jpg`
- Combined comparison: `/tmp/healthy-toggle-design-qa-softened.jpg`
- Source pixels: 1024 × 1536. Implementation pixels and simulator viewport: 368 × 800.
- Density normalization: source and implementation were proportionally fit to a shared 800-pixel comparison height without stretching. The selected visual target is the toggle component; ImageGen drift elsewhere on the source screen is excluded from fidelity findings.
- State: Focus selected for primary comparison; Quick selected captured and exercised as the secondary state.

## Full-view comparison

The implementation preserves the production fox, banner, screen spacing, cards, and floating create button. The replacement control matches the selected mockup's connected silhouette, dark-evergreen base, diagonal center seam, raised mint selected face, white selected outline, display lettering, and offset depth. It does not introduce a white backing band.

## Focused component comparison

The implementation uses the production `HealthyHabitCardBackground` image directly in the selected face. The stars and gradient therefore retain the exact source quality of the cards rather than using generated or code-drawn approximations. Both selected directions preserve the angled seam and keep labels centered with sufficient contrast.

## Required fidelity surfaces

- Fonts and typography: both labels use the app's Lilita One display face at 18 points. The selected label uses the approved black fill and white sticker outline; the inactive label is solid white.
- Spacing and layout rhythm: the 58-point control retains the screen's existing horizontal margins and separation from the banner and card list. Both halves provide full-height tap targets.
- Colors and visual tokens: the selected face reuses the card raster asset. The inactive face shares `LightSheet.healthyHabitsReward` with the card reward panel.
- Image quality and asset fidelity: the production 1122 × 1402 star artwork is rendered with high interpolation and clipped without regeneration.
- Copy and content: `Focus Habits` and `Quick Habits` are unchanged.

## Comparison history

1. Initial simulator pass found a P1 accessibility issue: the eight visual outline layers were exposed as repeated VoiceOver text. The decorative label layers were hidden and each button received one explicit accessibility label and selected value.
2. The same pass found a P2 readability difference from the mockup. Both labels increased from 16 to 18 points. The second capture confirms the larger labels fit both states without clipping.
3. User review found the pointed outer ends too sharp beside the rounded cards. The outer silhouette now uses continuous 14-point corners, the heavy outline was reduced from 4 to 3 points, and only the functional center seam remains angled. The final capture confirms the control now shares the cards' softer geometry without losing the selected-state distinction.
4. User review found the softened outer stroke was gray and inconsistent with every habit card. It now uses the same solid white 3-point border as the cards. The final simulator capture confirms there is no gray border remaining.
5. User review found the dark-green gap around the selected face too thin. The selected-face inset increased from 4 to 7 points, producing roughly 4 points of visible green between the two centered white strokes. The final capture confirms an even gap on the top, bottom, and rounded outer edge.

## Interaction checks

- Focus → Quick switch succeeded in Simulator.
- Quick habit content loaded after selection.
- Accessibility snapshot reports one `Focus Habits` button and one `Quick Habits` button, with only the active button marked `Selected`.

## Findings

No actionable P0, P1, or P2 differences remain.

## Follow-up polish

None required for the selected scope.

final result: passed
