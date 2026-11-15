# GAIA — project description for NASA Space Apps Challenge 2026 (Space Mission Design Game)

> Draft written by Claude (AI) on 15 Nov 2026 from the repository (`docs/CUMPLIMIENTO.md`, `docs/DATOS_NASA.md`,
> `scenes/b/docs/ARTE_Y_LICENCIAS.md`). Items marked **[TEAM: confirm]** are statements only the team can make.
> Everything else was checked against the repository. Paste into the submission form after the team reads it.

**Team:** Full Galácticos · Cajamarca, Peru
**Challenge:** Space Mission Design Game
**Game:** GAIA (working title) — desktop (Windows) and web versions, in English and Spanish

## Summary (short form)

GAIA is a 3D game where you design and then operate a robotic space mission. You choose a launcher, a trajectory, a rover
chassis, a power source, a communications antenna and science instruments, all under a real-feeling budget and mass limit.
Then you fly it: launch, cruise, landing, and six sols (Mars days) of operations on the surface of Mars (Jezero Crater) or the
Moon (south pole). Your goal is to send 100 units of science data back to Earth before the end of the sixth sol. Every design
choice has a consequence you can feel: too heavy and you cannot launch; too little battery and the rover stops at night;
no relay window and your data never reaches Earth. At the end, a report explains what happened and why, and compares your
mission with the real one.

## What the player does

1. **Design (workshop).** Pick a launcher (four real launchers shown at their real height: Delta II, Titan IIIE-Centaur,
   Atlas V 541, Saturn V), a trajectory, chassis, power, comms and instruments. Mass, cost, power and trajectory time are
   calculated live. A recommended design is provided for beginners.
2. **Go / No-Go review by role.** One to four players take the four classic roles (direction, engineering, science,
   communications) and vote before launch.
3. **Launch, cruise and landing** with real NASA photographs.
4. **Operate.** Drive the rover, analyse rocks, drill samples, build a small base (solar panels, domes, an antenna), and
   transmit data to Earth only while the communications link is open. A sol lasts 6 to 12 real minutes, chosen by the player.
5. **Unexpected events.** Nine events, each based on something that really happened to a NASA mission (solar conjunction,
   a rover stuck in sand, a memory fault, a micro-meteorite…), each with a decision and a visible consequence.
6. **Mission report** with causes, score and a comparison with the real mission.

## How it uses NASA data and resources

Every NASA figure, photo and model is listed with its source in `docs/DATOS_NASA.md`; game values (costs, masses at game
scale) are marked as game values and are **not** presented as NASA data.

- Mission facts from NASA/JPL: Mars 2020 launch and landing press kits (launch 30 Jul 2020 on an Atlas V 541, landing
  18 Feb 2021 in Jezero Crater, 203-day cruise, rover mass, MMRTG power, sol length, instruments, mission costs).
- Moon: NASA Science and NASA mission pages (Apollo 11, CAPSTONE, Saturn V, lunar surface temperatures, permanently
  shadowed regions with water ice).
- Official images from the NASA Image and Video Library, shown with their credit.
- 3D models from NASA 3D Resources: Perseverance, Ingenuity, Apollo Lunar Module and Saturn V.
- The four-segment mission framework (launch, space, ground, users) from the NASA resource *Design and Develop Science
  Missions*.

**Not used:** GMAT, Mission Viz, Concept Maturity Levels. The trajectories are a simplified game model, and the game says so.
Costs and masses are scaled down so a mission can be played in minutes.

## Technology

Godot 4.7.2 (GDScript). The code has three separate layers: data in JSON (`content/`), a pure simulation with no
graphics (`sim/`), and the view (`scenes/`). The simulation is covered by more than 600 automated tests (GUT) that pass.
Multiplayer (up to four players, one role each) runs over WebSocket. **It has been tested with several processes on one
computer, not yet on separate computers or over the internet.**

## Use of AI (declaration)

- **The idea, game design, rules and supervision are the team's.** **[TEAM: confirm in your own words]** The starting
  idea (design and operate a mission under limited mass, power and link) comes from the team's own ideas document.
- **Code:** most of the code was written with the help of Claude (Anthropic) working with the architecture and base classes
  the team created first. Some story, voice and integration blocks were assisted by Codex.
- **Images:** the logo, menu background, loading screen and story scene illustrations were generated with AI (Canva image
  generator) and carry the visible mark "Imagen generada con IA · AI-generated". The in-game interface, 3D scenes and
  terrain are rendered by the game itself.
- **Audio:** music and sound effects were synthesized by scripts in `tools/` (no recordings from other works). Radio voices
  are synthesized speech: Microsoft Windows voices (Spanish) and Piper (English: John, public domain; Joe, CC0; and a
  Spanish Piper voice under the Unlicense), with a walkie-talkie effect made by script.
- **3D models:** the NASA models come from NASA 3D Resources. The team's own models are documented in
  `scenes/b/docs/ARTE_Y_LICENCIAS.md`. **[TEAM: confirm authorship and licence of the five launcher and hangar models
  — see plan item 9.4.]**
- **Fonts:** Inter, Space Grotesk and Oxanium, all under the SIL Open Font License.
- No NASA logos or marks are used as the project's identity. GAIA is not affiliated with or endorsed by NASA.
  The official Perseverance model shows the badges the real rover carries; it is credited as a representation of NASA's rover.
- No faces or voices of real people (including anyone under 18) appear in the game or the demo.

## Known limits (stated plainly)

- Performance was measured on an Intel UHD integrated GPU: the mission runs at about 29 FPS on High and 59 FPS on Low
  (`docs/mediciones/v5_mision_y_plataforma_intel_uhd_antes_despues.txt`). The web version is a quick-test build.
- The English text has not been reviewed by a native speaker.
- Game balance after the latest battery change has not been verified by playing through.

## Links

- Source code and `docs/` folder: the project repository. **[TEAM: add the repository URL]**
- Playable web version: **[TEAM: add the published web link after the final merge]**
