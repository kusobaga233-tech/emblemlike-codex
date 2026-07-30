# Image-generation prompt registry

This registry plans future concept and raster work; it does not claim that any image has been generated, selected, reviewed, or approved. Every generated reference image or raster asset must use the user-specified `$imagegen` skill. Do not substitute another generator.

## Slug and version rules

- `$imagegen use-case slug`: lowercase kebab-case, prefixed by the category when useful, and identical to the asset registry URI suffix. Example: `hero-ember-warden`.
- Candidate versions: `<asset-id>-v01.png`, `<asset-id>-v02.png`, and so on. A version becomes selected only after an originality review and named reviewer decision.
- Generated file stays `Not generated` until the command has produced a real project file. Selected version stays `None` until review. Planned entries must never point at imaginary generated files.
- Originality review checks silhouette independence, costume and prop distinctness, absence of living-artist imitation, absence of protected franchise identifiers, and provenance/license notes.
- Production constraints are copied into the final prompt. Boss mesh budget equals hero mesh budget.

## Copyable entry template

### Asset ID

- `$imagegen use-case slug`:
- Final prompt:
- Generated file: Not generated
- Selected version: None
- Intended 3D/UI use:
- Reviewer: Unassigned
- License/source notes: Pending original generation via `$imagegen`; review provenance before selection.
- Originality review: Pending

## Planned prompt specifications

### Asset ID: hero-ember-warden-concept

- `$imagegen use-case slug`: `hero-ember-warden`
- Final prompt: Original turn-based tactical fantasy hero concept, Ember Warden, readable full-body silhouette, practical layered armor, ember oath motif expressed through geometric seams and a restrained warm accent, orthographic-friendly front and three-quarter views, neutral studio background, no text, no logos, no existing franchise or living-artist imitation.
- Generated file: Not generated
- Selected version: None
- Intended 3D/UI use: Hero 3D modeling reference and portrait planning.
- Reviewer: Unassigned
- License/source notes: Pending original generation via `$imagegen`; four hero prompts must remain visually distinct.
- Originality review: Pending

### Asset ID: boss-star-eater-concept

- `$imagegen use-case slug`: `boss-star-eater`
- Final prompt: Original tactical fantasy chapter boss, Star Eater, imposing but production-feasible silhouette, readable weak-point shapes, cosmic ash materials, front and three-quarter modeling reference, neutral background, no text, no logos, no franchise identifiers, no living-artist imitation. Boss mesh budget equals hero mesh budget; complexity must come from silhouette and material blocking rather than extra geometry.
- Generated file: Not generated
- Selected version: None
- Intended 3D/UI use: Boss 3D modeling reference, encounter portrait, and scale comparison.
- Reviewer: Unassigned
- License/source notes: Pending original generation via `$imagegen`; mesh-budget parity is mandatory.
- Originality review: Pending

### Asset ID: environment-chapter-one-concept

- `$imagegen use-case slug`: `environment-chapter-one`
- Final prompt: Original isometric tactical arena concept for a ruined ember observatory, modular square grid readability, clear deployment and objective landmarks, restrained ash-and-ember palette, gameplay-first negative space, production-feasible reusable kit, no characters, no text, no logos, no franchise identifiers, no living-artist imitation.
- Generated file: Not generated
- Selected version: None
- Intended 3D/UI use: Environment modular-kit planning, lighting reference, and viewport readability checks.
- Reviewer: Unassigned
- License/source notes: Pending original generation via `$imagegen`; concept may guide but cannot override greybox gameplay framing.
- Originality review: Pending

### Asset ID: ui-chapter-one-styleboard

- `$imagegen use-case slug`: `ui-chapter-one-styleboard`
- Final prompt: Original tactical RPG UI styleboard, ember oath geometry, high-contrast command states, keyboard focus clarity, scalable panels and icons, 16:9 and portrait-safe composition examples, neutral labels made from abstract bars rather than readable text, no logos, no franchise identifiers, no living-artist imitation.
- Generated file: Not generated
- Selected version: None
- Intended 3D/UI use: UI art direction only; final controls remain native accessible Godot UI.
- Reviewer: Unassigned
- License/source notes: Pending original generation via `$imagegen`; generated text is never shipped.
- Originality review: Pending

### Asset ID: vfx-chapter-one-styleboard

- `$imagegen use-case slug`: `vfx-chapter-one-styleboard`
- Final prompt: Original tactical fantasy VFX styleboard showing attack, support, resonance, objective, and boss telegraph shapes, strong timing silhouettes, color-blind-safe value separation, dark neutral background, sprite-sheet planning panels without text, no logos, no franchise identifiers, no living-artist imitation.
- Generated file: Not generated
- Selected version: None
- Intended 3D/UI use: VFX shape-language and sprite/particle implementation reference.
- Reviewer: Unassigned
- License/source notes: Pending original generation via `$imagegen`; final effects require gameplay readability review.
- Originality review: Pending
