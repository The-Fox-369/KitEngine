# KitEngine 🦊

### Make games. Not excuses.

**A modular, open-source game engine built for developers who want useful tools, control over their projects, and room to create.**

Welcome to **KitEngine** — an ambitious game engine project with a simple idea:

**Give developers a lot of good stuff. Don't force all of it into their games.**

We're calling that **GOOD BLOAT**.

Yes, seriously.

> [!IMPORTANT]
> **Status: PLANNED / PRE-ALPHA.** KitEngine is not a usable game engine yet. This repository currently documents what we're building, not features that already exist. No editor to download. No renderer to benchmark. **Zero triangles rendered.** We're working on that last part first.

---

## GOOD BLOAT™ — Wait. Isn't bloat bad?

Usually? **YES.**

But KitEngine's philosophy is a little different:

- **The engine can be feature-rich.** Rendering, scripting, visual tools, assets, and more should be available as the project grows.
- **Your project gets to choose.** Use the modules you need; ignore the ones you don't.
- **Exports should stay lean.** The long-term goal is to avoid bundling unused engine modules into finished games where technically practical.
- **Performance matters.** Features are welcome. Unnecessary overhead isn't.

**GOOD BLOAT = lots of useful possibilities, not lots of unnecessary baggage.**

We want a toolbox, not a backpack full of bricks.

---

## What are we actually building?

Here's the plan. These are **goals**, not a list of completed features.

| Part | The idea |
| --- | --- |
| **KitEngine Core** | A Dart-based foundation for projects, scenes, runtime systems, and modules. |
| **Renderer** | **OpenGL first**, with a design that can support other graphics backends later. |
| **KitEngine Editor** | A Flutter/Dart desktop editor for building and managing games visually. |
| **KitDen** | A Flutter/Dart launcher and project hub for local projects and installed engine versions. |
| **KitScript (`.kitsc`)** | A custom scripting language designed for KitEngine. Start understandable; optimize when it makes sense. |
| **KitTheme (`.kitth`)** | A visual, customizable theming system. Your editor should feel like *your* workspace. |
| **Optional AI Helper** | Help with development, but only with explicit user control over what it can access or change. |
| **KitEngine Cloud** | Optional, account-based backup and sync for people who *want* it. Not a requirement for local development. |

The architecture will evolve as real code, benchmarks, and user feedback teach us what actually works.

### And the platforms?

**Windows and Linux** are the initial targets. macOS support may be possible later if there is someone able to maintain and test it properly.

No pretending every platform is supported before anyone has even opened a window.

---

## Local-first. Always.

You should be able to launch KitEngine, create a project, make a game, and export it **without creating an account**.

No login wall. No forced sync. No surprise uploads.

**Local work is the default. The cloud is an option.**

| You want to... | Need an account? |
| --- | --- |
| Use KitEngine locally | **No** |
| Write KitScript | **No** |
| Create and keep KitTheme files private | **No** |
| Build and export a local game | **No** |
| Back up projects to KitEngine Cloud | **Yes — opt-in** |
| Access your private cloud projects in the web dashboard | **Yes** |
| Share cloud projects with collaborators (future feature) | **Yes, with permissions** |

### Cloud, but without the hostage situation

The long-term cloud plan is one account shared across **KitDen**, the **KitEngine Editor**, and a separate **web dashboard**.

Cloud projects should have local working copies, versioned backups, and conflict handling. Losing your internet connection must not mean losing your ability to work.

The web dashboard is for managing projects, backups, devices, and account settings — **not secretly a second game editor**.

And signing into the cloud must **not** silently grant the AI Helper access to your projects.

**Your files. Your choice.**

---

## KitScript — because we want our own language

**KitScript (`.kitsc`)** is the planned scripting language for KitEngine.

The goal is to make scripts approachable while leaving room for more powerful systems over time. The initial direction is a readable, interpreter-first implementation; more advanced execution approaches can come later if they are justified.

No, there isn't a working KitScript runtime yet.

**Yes, writing one is on the to-do list.**

---

## KitTheme — make the editor yours

**KitTheme (`.kitth`)** is the planned theming format, paired with visual theme-editing tools.

Want a quiet, dark workspace? Great.

Want a theme that looks like a spaceship control panel? Also great.

Want to keep your theme private? **That's your call.**

KitEngine shouldn't demand ownership of the original games, themes, or scripts you create with it. Third-party content may have its own license terms, so always check those separately.

---

## Meet Kuro 🦊

Kuro is a **black fox**.

He's the mascot of KitEngine and the planned face of the optional AI Helper.

He is **not** required to run the engine.

He does **not** approve your uploads.

He does **not** delete your projects.

He does **not** secretly synchronize your private files.

**HE IS NOT THE DATABASE ADMINISTRATOR.**

**HE IS A BLACK FOX.**

**HE IS JUST THERE.**

(And honestly? That's enough.)

---

## What works right now?

**Not the engine. Yet.**

This repository starts with planning and documentation. Let's not pretend a README is a rendering backend.

### The first actual mission

1. Open a desktop window.
2. Create an OpenGL context.
3. Clear the screen.
4. **Render one triangle.**
5. Handle basic input.
6. Measure performance and make sure the foundation works on real hardware.

Then we can work toward scenes, assets, scripting, the editor, and everything else.

**One triangle first. The universe later.**

### A note on hardware

Development includes testing on an older Linux laptop with an aging NVIDIA GPU. That's useful for catching performance and compatibility problems early — but it is **not** a replacement for testing on other hardware and operating systems.

If the ancient laptop complains, we listen. If a modern machine complains, we listen to that too.

---

## Roadmap (the very honest edition)

These are **planned directions**, not promises of dates or completed milestones.

- [ ] **Foundation:** Window, graphics context, triangle, input, and basic diagnostics.
- [ ] **Core systems:** Project loading, scenes, assets, and a modular runtime.
- [ ] **Scripting:** First usable KitScript implementation.
- [ ] **Editor:** A practical Flutter-based editing workflow.
- [ ] **Customization:** KitTheme and visual theme tools.
- [ ] **Build pipeline:** Package projects while excluding unnecessary modules where practical.
- [ ] **KitDen:** Local project and engine-version management.
- [ ] **Optional cloud:** Accounts, web dashboard, versioned backups, and safe synchronization.
- [ ] **Maybe much later:** More rendering backends, collaboration, and other features justified by actual needs.

The roadmap will change. That's called development, not betrayal.

---

## Want to help?

**YES, PLEASE.**

You don't need to show up with a completed graphics engine in your pocket.

Architecture discussions, bug reports once there's software to test, documentation suggestions, performance measurements, and thoughtful code contributions are all welcome as the project takes shape.

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) for the contribution guidelines.

One request: **don't describe planned features as if they're already implemented.** We want enthusiasm *and* honesty.

---

## License and your creations

**KitEngine is licensed under the MIT License.** See [`LICENSE`](LICENSE).

The MIT License permits use, modification, and redistribution of the licensed engine code, including in commercial contexts, subject to its notice conditions.

**Games, original scripts, and original themes you make are yours to license and share — or not share — as you choose.** Using an MIT-licensed engine doesn't by itself force you to open-source your own creations.

Third-party assets, dependencies, and templates may have separate licenses.

---

## The short version

**Open-source engine. Modular by design. Offline-first. Optional cloud. Custom scripting. Custom themes. A black fox.**

We're not building this to impress investors with buzzwords.

We're building it because **making games should be fun**, and building the tools to make them should be fun too.

**KitEngine: GOOD BLOAT. BETTER GAMES.** 🦊

*Current triangle count: 0. Subject to change.*
