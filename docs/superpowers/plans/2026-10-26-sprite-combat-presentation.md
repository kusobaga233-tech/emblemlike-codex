# Sprite combat presentation implementation

Goal: Add readable attack actions and effects without 3D characters, body-part cutouts or new combat rules.
Architecture: A deterministic presentation queue consumes resolved events, never changes BattleSession, and sequences whole-sprite anticipation/release/recovery, projectile travel and hit/heal timing. Logical roots/pick areas stay on cells; only Sprite3D children move. Battle input/results wait until playback drains. HUD and audio consume presented events at their cue times. Existing VFX remain for non-sequenced fixtures and terminal/resonance effects.

- [ ] Tests first: time-resolved HP/hit/defeat, queued counterattacks, sprite displacement/recovery, ranged projectile, heal, cancellation/reconfigure cleanup and unchanged rule state.
- [ ] Implement SpriteCombatPresentation and lightweight procedural SpriteCombatFx; fixed main attack profiles melee/thrust/bow/magic/heal, no animation skeletons.
- [ ] Wire scene input gate, presentation-driven HUD/result dispatch, and expose basic healing through the action menu.
- [ ] Full test/validator regression, non-headless timed captures, Windows standalone export/boot, deliver paths with limitations.

Timing target: anticipation 0-180ms, melee impact 300ms / bow 420ms / magic/heal 340ms, recovery ends 700ms. Serial strikes/counters avoid instant simultaneity. Event-derived combat outcome remains deterministic and committed before presentation. Decline excessive input instead of double-applying commands. Manual camera orbit remains independent.
