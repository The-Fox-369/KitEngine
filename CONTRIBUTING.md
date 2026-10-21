# Contributing to KitEngine 🦊

### Come build a game engine. We currently have zero triangles.

Hey! Welcome to **KitEngine**.

First of all: **thanks for even considering helping out.** Whether you've written ten graphics engines or are just learning Dart, there's room for useful ideas, questions, documentation, testing, and (eventually) code.

KitEngine is an open-source, Dart-based game engine project built around **GOOD BLOAT**: lots of genuinely useful tools, modular architecture, and exported games that don't have to carry features they never use.

The goal is simple: **make game development easier without making game developers fight their own tools.**

> [!IMPORTANT]
> **CURRENT STATUS: PLANNING / PRE-ALPHA.** The design is more developed than the actual engine. There is no working renderer, editor, KitScript implementation, KitDen, or KitTheme system yet. **Triangles rendered: 0.** Please don't file a bug saying the editor won't open. There isn't an editor to open. 😭

If you haven't already, read the [README](README.md) for the short introduction and the project's detailed design documents where available. **Everything described as planned is a goal, not an existing feature.**

---

## 1. What can I contribute *right now*?

**More than you think.** We don't need to wait for a working engine to have useful conversations.

| Contribution | Useful now? | Examples |
| --- | --- | --- |
| **Ideas and design feedback** | **YES** | Better editor workflows, module boundaries, accessible controls |
| **Architecture discussions** | **YES** | Scene formats, rendering interfaces, asset IDs, scripting design |
| **Documentation improvements** | **YES** | Fix confusing explanations, correct examples, catch contradictions |
| **Code and prototypes** | **YES, with coordination** | A small isolated window/OpenGL proof of concept |
| **Testing** | **As builds become available** | Linux/Windows compatibility, performance, GPU-specific bugs |
| **Art and UX proposals** | **YES, with discussion** | Theme editor concepts, icons, discoverability improvements |
| **Translations** | **Later, once text and workflows stabilize** | Please don't translate 50 pages of moving targets yet |
| **Cloud infrastructure** | **Not the first milestone** | The local engine gets to exist before we deploy an empire |

You do **not** need to be a professional programmer to contribute. Clear descriptions of confusing UX can be as valuable as a clever optimization.

> [!TIP]
> **First milestone:** create a window, initialize an OpenGL context, clear the screen, render one triangle, handle input, and measure what happened. If you want to help with code, that's a fantastic place to start.

---

## 2. Before you build an entire civilization

Please check whether someone has already proposed your idea or started working on it.

1. Read the current [README](README.md) and any relevant design sections.
2. Check the repository's [Issues](https://github.com/The-Fox-369/KitEngine/issues) for related work.
3. If your idea changes a core system, **start a discussion in an issue first**. A short proposal is enough.
4. For a small typo or obvious documentation fix, a direct pull request is completely fine.
5. Be ready for designs to change after we actually implement and test them.

**Why discuss big changes first?** Because surprise-replacing the entire rendering architecture in a 7,000-line pull request is a rather dramatic introduction.

**Small, understandable contributions beat giant mystery boxes.**

---

## 3. The KitEngine rules (the ones that actually matter)

### GOOD BLOAT, not accidental bloat

- **Useful built-in features are welcome.** Developers shouldn't need seven unrelated plugins for normal tasks.
- **Modules need boundaries.** A game using 2D sprites shouldn't be forced to ship ragdoll physics, multiplayer tools, and the editor.
- **Performance matters.** Don't add per-frame allocations or heavyweight dependencies without a good reason.
- **Explain trade-offs.** If a new feature costs RAM, startup time, complexity, or build size, say so.
- **Avoid feature collecting.** A long checklist doesn't help if everything is half-finished.

### Local-first means LOCAL-FIRST

- Projects must be usable **without an account or an internet connection**.
- Cloud backups and synchronization are **optional and opt-in**.
- Never silently upload someone's project, theme, scripts, or assets.
- Never overwrite local files because a different device had an older copy.
- The optional AI Helper must **not** gain access to projects or write changes without proper user control.

### Make the engine pleasant to use

- Prefer clear error messages over unexplained failures.
- Keep editor actions discoverable and predictable.
- Consider keyboard navigation, contrast, text scaling, and accessible UI states.
- Avoid hiding essential functionality behind obscure shortcuts.
- Respect existing files, project structures, and user preferences.

**The developer should spend their time making games, not negotiating with the engine.**

---

## 4. Technology: what are we building with?

The current direction is:

| Area | Planned technology |
| --- | --- |
| Engine core / runtime | **Dart** |
| KitEngine Editor | **Flutter + Dart** |
| KitDen launcher / project hub | **Flutter + Dart** |
| Game scripting | **KitScript (`.kitsc`)** |
| Editor themes | **KitTheme (`.kitth`)**, designed around a visual theme editor |
| First renderer | **OpenGL**, initially GLSL shaders |
| Future renderer backends | **Vulkan / Direct3D**, when there's a reason and people to maintain them |
| Initial platform targets | **Windows and Linux** |
| macOS | Possible community-supported target later, **not currently promised** |
| Local app metadata | **SQLite where useful** |
| Optional future cloud | API + PostgreSQL + private object storage |

**Please don't rewrite the whole project in a different language without talking to us.** Dart was chosen deliberately. Native code or FFI may make sense for specific, measured needs; they don't need to become the entire project.

> [!NOTE]
> **Planning choices aren't eternal laws.** Strong evidence, maintainability, and actual working prototypes are better arguments than “everyone uses this framework.”

---

## 5. Contributing code (once there is code)

There isn't a finalized build workflow yet. **Do not assume the commands below already work in a documentation-only repository.** When actual Dart and Flutter projects exist, this will be the intended general approach:

1. Fork the repository (or work in a branch if you have write access).
2. Create a branch with a useful name, such as `feat/opengl-window`, `fix/asset-rename`, or `docs/kitscript-guide`.
3. Make a **focused** change. Separate unrelated refactors.
4. Add or update tests when there is testable behavior.
5. Format and analyze code with the tools appropriate to the affected package.
6. Open a pull request describing **what changed, why, and how you checked it**.

Typical future Dart commands (run in the relevant package once it exists):

```bash
dart format .
dart analyze
dart test
```

For Flutter apps, the usual equivalents include `flutter analyze` and `flutter test`. The exact commands, package layout, and CI rules will be documented **after the project structure exists**.

**Please don't invent a passing test suite for code that hasn't been written.** A note saying “not tested; no runnable implementation exists yet” is genuinely helpful.

### Code we can understand next month

- Favor readable names and small, coherent components.
- Comment the *why*, especially around performance tricks and platform quirks.
- Keep stable public APIs in mind; don't break them for cosmetic reasons once they exist.
- Avoid unnecessary dependencies; explain new dependencies in your pull request.
- Keep platform-specific code behind suitable interfaces.
- Don't introduce an entirely new architecture because you wanted to move one button.

**Clever is nice. Maintainable is nicer.**

---

## 6. Rendering contributions: make the triangle exist first

KitEngine starts **OpenGL-first**, but shouldn't be stuck to OpenGL forever.

A good renderer contribution should:

- Fit behind the renderer abstraction rather than infect unrelated engine systems.
- State supported graphics/API versions and important driver assumptions.
- Handle missing capabilities gracefully where possible.
- Avoid silently requiring a newer GPU when an older path would work.
- Include reproducible test steps or a tiny sample scene when practical.
- Measure performance using repeatable conditions, not vibes alone.

**Please test on modest hardware when you can.** KitEngine's development hardware includes an older HP laptop with an NVIDIA GT 740M on Linux. If something works there, great—but that's **one test machine**, not proof it works everywhere.

We also want Windows/Intel graphics testing, and eventually other AMD/NVIDIA hardware. You do **not** need an RTX 5090 to be useful.

> [!TIP]
> A future tutorial/sample scene should double as a repeatable performance test. **It's educational. It's also a debugger wearing a fake mustache.**

---

## 7. KitScript contributions (`.kitsc`)

KitScript is **planned**, not implemented. The initial design favors a readable language and a straightforward **lexer → parser → AST → interpreter** route before considering more advanced execution models.

If you're proposing KitScript features:

- Show a small `.kitsc` example of how developers would actually use them.
- Explain syntax, expected behavior, errors, and edge cases.
- Keep the language understandable; avoid adding syntax just because another language has it.
- Consider diagnostics and editor tooling, not only runtime behavior.
- Prefer one consistent language implementation and reusable tooling over five parsers that disagree.
- Treat a VM, bytecode compiler, JIT, and other optimizations as **future decisions to justify with evidence**.

### A helpful proposal looks like this

```text
Feature: [short name]
Problem: [what game developers struggle with]
Example: [tiny .kitsc sample]
Expected behavior: [what should happen]
Questions / trade-offs: [anything uncertain]
```

The KitScript language server and outside-editor integrations (for example VS Code/Cursor) can come later. First, the language itself needs to work.

---

## 8. KitTheme contributions (`.kitth`)

**KitTheme is not meant to be a second programming language.** It's a portable format behind a **visual theme editor**.

Contributions should prioritize:

- Easy editing through GUI controls and instant previews.
- Readable, portable `.kitth` files.
- Clear handling of missing keys and incompatible theme versions.
- Reasonable contrast and accessibility checks.
- Good import/export behavior.
- Theme ownership: **users may keep their original themes private**.

You don't have to publish your theme for KitEngine to respect it. Nor should applying a theme upload it to the cloud.

If you're proposing official themes or showcasing community themes, **make sure you have permission to distribute the assets involved**.

---

## 9. KitDen and editor contributions

**KitDen** is the planned launcher/project hub. The **KitEngine Editor** is the workspace where games get made. They're related, but they're not the same app.

Useful future areas include project/version management, clear error messages, discoverable tool panels, viewport usability, asset workflows, undo/redo, and smooth iteration.

Some important expectations:

- **Don't force sign-in to open a local project.**
- Don't make updating an engine version silently destroy an existing project's compatibility.
- Don't make hot reload lose unsaved edits or silently corrupt data.
- Keep exported games independent of the entire Flutter editor installation.
- Give users meaningful control over what gets installed, downloaded, synchronized, and deleted.

And yes, customization matters. The editor shouldn't require every developer to enjoy the exact same shade of gray.

---

## 10. Cloud and AI proposals: later, carefully

There is a detailed plan for optional accounts, cloud projects, a web dashboard, backups, and cross-device synchronization.

**That does not mean we are building an online services company before we've rendered a triangle.**

For any future cloud contribution, treat these as non-negotiable design requirements:

- Local projects remain independent of cloud availability.
- Sync and backups are **explicit, private, and user-controlled**.
- Server-side authorization protects every private project and file.
- No client-side secret keys or privileged database credentials.
- Conflicts must not silently discard user changes.
- Account deletion, data export, and session revocation need real consideration.
- AI project access is a **separate permission decision**, not a side effect of signing in.

**Kuro is the black fox mascot and proposed optional AI Helper face.** Kuro does not silently upload your files, authorize deletion, or manage PostgreSQL.

**HE IS NOT THE DATABASE ADMINISTRATOR. HE IS A BLACK FOX. HE IS JUST THERE.** 🦊

---

## 11. Found a bug? Excellent. Please explain it.

Once there are runnable builds, useful bug reports should include:

```text
What happened:
What you expected instead:
Steps to reproduce:
KitEngine version or commit:
Operating system and version:
GPU / driver / graphics API (if relevant):
Logs or error messages (with secrets removed):
Screenshots or a minimal sample project (if safe to share):
```

**Minimal reproductions are wonderful.** A 12-line example is easier to debug than an unexplained 8 GB project archive.

Do not publicly post tokens, passwords, private project archives, or other people's data. If a project is private, make a smaller sanitized example instead.

### Have a feature idea?

Tell us **the problem first**, then your proposed solution. “I'd like one-click input rebinding because…” helps more than “add 900 settings.”

### Found a security vulnerability?

**Please don't publish an exploit or private credentials in a public issue.** Use GitHub's private vulnerability reporting feature **if the repository has it enabled**. Otherwise, first ask maintainers through an appropriate non-public channel how to report it safely. We'll document a dedicated process when one exists.

---

## 12. Pull requests: help us understand the change

A good pull request answers four questions:

1. **What** did you change?
2. **Why** is it needed?
3. **How** did you test or validate it?
4. **What** still needs work or review?

For UI changes, screenshots or a short recording are useful. For performance changes, give the machine, workload, before/after measurements, and how you measured them. For API or file-format changes, describe compatibility implications.

Here's a tiny template you can copy:

```md
## What changed?

## Why?

## Testing / validation

## Compatibility or risks

## Related issue (if any)
```

Before submitting, check:

- [ ] This PR has a focused purpose.
- [ ] I didn't present planned behavior as already implemented.
- [ ] I've explained new dependencies and significant architectural changes.
- [ ] I added tests or explained why tests aren't possible yet.
- [ ] I've considered Windows/Linux behavior where relevant.
- [ ] I haven't included secrets, private project files, or unlicensed assets.
- [ ] I haven't accidentally replaced someone else's work with my own assumptions.

There's no guaranteed review time and no promise that every feature will be accepted. A declined idea isn't a personal attack; sometimes the scope or timing just isn't right.

---

## 13. Be decent to other humans

Open-source development works better when people can disagree without turning every design discussion into a boss fight.

- Be respectful and patient, especially with beginners.
- Critique ideas and code, not people's intelligence or identity.
- Don't harass, threaten, spam, or discriminate.
- Don't pressure people to share private files or personal information.
- Assume good intent where reasonable; ask questions before declaring disaster.
- Maintainers may moderate or close discussions that become abusive or persistently disruptive.

It's okay to say **“I don't think that design works.”** It's not okay to be cruel about it.

**We want energetic developers, not a hostile comment section.**

---

## 14. Licensing and ownership

KitEngine uses the **MIT License**; see [`LICENSE`](LICENSE).

By submitting a contribution, you confirm you have the right to contribute it and agree it may be distributed under the project's MIT License. Preserve required third-party notices, and **don't submit code, art, audio, or assets you don't have permission to license**.

**Games, original KitScript code, and original KitTheme creations made with the engine belong to their creators.** The MIT License on the engine does not automatically require users to publish their games or themes.

If a contribution brings in third-party dependencies or assets, clearly describe their licenses and any restrictions before they are merged.

---

## 15. The contribution roadmap, approximately

**Now:** discuss architecture, clarify documentation, build focused prototypes, and make the first window/triangle actually happen.

**Next:** input, rendering foundations, scenes, assets, basic scripting, and a usable development loop.

**Later:** editor workflows, KitTheme, KitDen, modules, exports, and real cross-platform testing.

**Much later:** optional cloud features, collaboration, advanced backends, and whatever real needs justify.

This order can change. A roadmap is a direction, not a sacred prophecy.

---

## 16. The short version

**Want to help? AWESOME.**

- Start with a real problem or a small useful improvement.
- Talk before changing the foundations.
- Keep KitEngine modular, readable, fast, and local-first.
- Care about beginners, modest hardware, Windows **and** Linux.
- Respect people's files, themes, creations, and privacy.
- Don't claim something works until somebody actually runs it.
- Make games easier to create. That's why we're here.

**KitEngine: GOOD BLOAT. BETTER GAMES.** 🦊
