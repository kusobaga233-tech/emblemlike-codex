# Aurelia cutout QA sample limitations

This isolated sample uses three cleaned formal-art layers: `body_no_sword_no_head.png`, `clean_head.png`, and `clean_weapon_hand.png`. Each is attached to its corresponding body, head, or weapon bone. The original assembled `aurelia_full.png`, broad `oathblade.png` extraction, and intermediate `clean_oathblade.png` are not rendered, preventing duplicate swords or a disconnected floating hand.

The head and cleaned weapon-hand group now move independently, while the remaining torso, limbs, hair tails, clothing, and cape stay combined in the body layer. The weapon bone is aligned to the manifest's wrist / visible-grip pivot. The source illustration still does not expose pixels hidden behind overlaps, so extreme body deformation is intentionally avoided and no hidden wrist geometry is invented.

This proves three-layer formal-art ingestion, head/weapon transform ownership, and the animation/event interface. Production-quality limb, hair, and cloth deformation still requires a layered redraw with overlap-safe margins.
