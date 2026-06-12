# TODO — BuildNDash2D

Living checklist. Items are checked (`[x]`) when done — never deleted.

## Project setup

- [x] Godot 4.x project (`project.godot`, GL Compatibility renderer for Web + Android + iOS)
- [x] Entry scene `scenes/main.tscn` + code-built UI
- [x] `Net` autoload (`scripts/net.gd`) — LOCAL / HOST / CLIENT, port 7803
- [x] Repo files: README, LICENSE, EULA, PRIVACY_POLICY, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, AGENTS.md, TODO.md, .github templates, .gitignore

## Core gameplay

- [x] Runner: auto-run (world scroll), jump, slide with hitbox shrink (`scripts/runner.gd`)
- [x] Server timeline: speed ramps 280 → 560 px/s
- [x] Builder Pro toolbar: Block, Spike, Trampoline, Moving Platform, Shield (2s cooldown)
- [x] Grid-snapped placement, forced ahead of the Runner
- [x] Hazards: spikes kill, block side-hit kills; trampolines bounce
- [x] Moving platforms: deterministic sine motion from shared timeline
- [x] Shield power-up: absorbs one hit (radius pickup)
- [x] EDM visuals: background hue drift + beat flash (~128 BPM)
- [x] Distance score HUD + cooldown bar + shield indicator
- [x] Game over panel + restart + back to menu

## Modes

- [x] Local (same device): left half = Runner, right half = Builder Pro
- [x] Offline LAN: host + client by IP (`ENetMultiplayerPeer`)
- [x] Local Server: strict host-side validation (cooldown, tool id, bounds, min distance ahead)
- [x] State sync: unreliable snapshot (runner, scroll, timeline, score, shield) + reliable spawn/consume/restart RPCs

## Polish / pending

- [ ] Manual playtest: balance speeds, cooldown, object sizes
- [ ] LAN playtest on two devices
- [ ] Camera triggers (zoom/shake events from spec) — currently only beat pulse
- [ ] More power-ups (speed boost, slow-mo)
- [ ] Builder cursor preview (ghost object before placing)
- [ ] Particles on death / bounce / pickup
- [ ] Music synced to beat timer — CC0 or original EDM track
- [ ] Sound effects (jump, place, death) — CC0 or original
- [ ] Pause menu
- [ ] High score persistence (local save)
- [ ] Web export preset + test in browser
- [ ] Android + iOS export presets + test on device
- [ ] App icon final art + splash screen

## Wishlist

- [ ] Online multiplayer: dedicated headless server + matchmaking/relay
- [ ] Level checkpoints / longer structured levels
- [ ] Role swap option
