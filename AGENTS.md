# AGENTS.md — Rules for AI coding agents

Read this file in full at the start of every session, before doing anything else. Then read `DECISIONS.md`, `PROGRESS.md` and `ghosted-movers-spec.md`.

## Project

- **Game:** Ghosted Movers, a 2–4 player physics party game for the Artificial Arcade hackathon (PS02: Chaos Control), built in 24 hours.
- **Design source of truth:** `ghosted-movers-spec.md`. It defines the mechanics, numbers, architecture, network protocol, folder structure and build phases.
- **Engine:** Godot 4, 3D. Phones are controllers over a local WebSocket bridge; one shared projector screen.
- **Renderer:** Mobile.
- **Development environments:** two developers on different operating systems. Everything must work on any OS (rule 7).

## 1. Workflow: plan, wait for go, build

For every task:

1. **Plan first.** Post a short plan:
   - the goal,
   - the files you will create or change,
   - your approach,
   - how you will verify it works.
2. **Wait for an explicit "go"** from the user before writing or changing anything.
3. **Build** what the plan said.
4. **Report back** in a few lines: what changed, how you verified it, anything left unfinished.
5. **Update `PROGRESS.md`.**

If the work turns out to need something the approved plan did not cover, stop and post an updated plan. Do not silently expand scope.

## 2. Design changes: ask first

Do not change any design decision without the user's approval. This covers:

- mechanics,
- numbers in the spec,
- arenas,
- scoring,
- the network protocol,
- the folder or scene structure.

When the spec is unclear, ask; never guess. Once the user approves a change:

1. Log it in `DECISIONS.md`.
2. Update `ghosted-movers-spec.md` to match.

## 3. What you are free to do

The user has given you full freedom to:

- run any command, including launching Godot, headless checks and test scenes,
- create, edit or delete any file in the repository,
- install Godot addons, npm or pip packages, and download assets.

This freedom applies inside an approved plan (rule 1). Assets must match the spec's art direction: CC0 low-poly packs in one consistent style.

## 4. Git

- You may commit and push on your own.
- **Before every push, tell the user** what is being pushed and to which branch.
- Follow the Git rules in the spec:
  - `.godot/` is ignored,
  - `.uid` files are committed,
  - commits are small and frequent.

## 5. Code style

- GDScript, following Godot's official GDScript style guide.
- The style details are your choice. State them in your first plan, log them in `DECISIONS.md` once approved, and apply them consistently everywhere.
- Every tunable number lives in `autoload/Balance.gd`, as the spec requires.

## 6. Docs you must keep updated

| File | Update when |
| --- | --- |
| `PROGRESS.md` | After every task: tick what is done, note what is in progress or blocked |
| `DECISIONS.md` | Every time the user approves a decision |
| `ghosted-movers-spec.md` | Every time an approved decision changes the design |

These three files must never contradict each other.

## 7. Keep everything OS-neutral

- No OS-specific paths, scripts or tools in the project. Inside Godot, use `res://` and `user://` paths.
- When a command differs between operating systems, give each variant.
- Don't assume which OS the user is on; ask if it matters.
- Never commit machine-specific files. `.godot/` stays ignored; editor settings live outside the repo.
