# AGENTS.md — BuildNDash2D (advanced 2D Runner)

Advanced 2D asymmetric co-op runner, Geometry Dash inspired, featuring:
- longer levels
- power-ups
- trampolines
- moving platforms
- camera triggers
- dynamic visual effects

> All code, comments, and docs in English, with good meaningful comments.

## Players
- **Player A (Builder Pro):** places advanced objects, traps, moving platforms. Floating cursor with advanced tools.
- **Player B (Runner):** runs automatically, jumps, slides, activates power-ups.

## Modes
1. **Local (same device):** split touch controls.
2. **Offline LAN (no internet):** host + client over local IP (`ENetMultiplayerPeer`).
3. **Local Server:** host runs an authoritative internal server that controls:
   - level timeline
   - speed
   - triggers
   - moving platforms

## Technical requirements
- Godot 4.x (GDScript)
- Web (HTML5) + Android + iOS export
- 2D runner physics system (auto-run, jump, slide, trampolines)
- EDM-style visual effects (glow, particles, beat pulses)
- Builder with advanced tools
- Modular code (logic / networking / UI separated)
- Independent project: do NOT share anything with the other games in the monorepo

## Art style
Neon + clean geometry, glow, EDM aesthetic. Original art or CC0.

---

## 🟩 FREE copyright-free assets (CC0)

### 🎨 2D Sprites / Tiles / UI
- Kenney.nl → https://kenney.nl/assets
- Itch.io CC0 Assets → https://itch.io/game-assets/free/tag-cc0
- OpenGameArt (filter CC0) → https://opengameart.org
- CraftPix Free → https://craftpix.net/freebies/
- GameDev Market Free → https://www.gamedevmarket.net/category/free/

### 🔊 Sound and music
- Kenney Audio
- Freesound.org (filter CC0)
- Mixkit
- OpenGameArt Audio

## 🟦 AI-generated assets
- Leonardo.ai, Flux/Midjourney, Stable Diffusion (local)

### Base prompt
> "2D game assets, flat style, clean shapes, neon glow, EDM aesthetic, CC0 style, simple silhouettes, bright colors, for a mobile game"

---

## Wishlist (not implemented yet)

- **Online multiplayer:** current netcode is LAN-only (ENet over local IP, manual IP entry). Future: dedicated server reachable over the internet + matchmaking/relay. The authority model is already server-side (host validates everything in "Local Server" mode), so the migration path is extracting the host logic into a headless Godot server.
