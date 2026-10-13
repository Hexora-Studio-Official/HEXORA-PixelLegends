# Instructions for coding agents

## Read the canonical specification first

Before proposing or making changes, read the complete [`docs/PROJECT_SPEC.txt`](docs/PROJECT_SPEC.txt). It is the canonical source for PixelLegends' product goals, visual direction, architecture, systems, phased development plan, phase gates, and live project status. Read the status/handoff block at the top and inspect the repository to confirm it is still accurate.

`README.md` is only a quick-start page. Do not create competing roadmaps, architecture documents, or status summaries. If a task changes project status, update the live handoff block in `docs/PROJECT_SPEC.txt` with the date and verifiable evidence.

## Scope and sequencing

- Treat the full MOBA design as the **long-term target**, not authorization to implement every feature now.
- The currently approved workstream is the client visual shell, environment, documentation, and validation. Do not add MOBA gameplay, active matchmaking, online authentication, networking, or dedicated-server behavior unless the user explicitly approves that next scope.
- The current sign-in behavior is local Guest only. Keep Play and Google login inactive until their implementation is approved.
- Follow the phase sequence in section 26 and do not claim a phase is complete unless its acceptance criteria are met and tested. Stop and debug a failing phase before building on it.
- If the live status and repository differ, verify the code and tests, then correct the status. Never infer implementation from a design requirement.

## Repository safety and architecture

- Preserve uncommitted user work. Never reset, clean, or replace the checkout wholesale.
- The current project uses a Godot root project and a `src/` layout. The `client/server/shared` tree in the specification is a logical target, not a reason to move files en masse.
- Some earlier shooter-era resources and services remain. Treat them as legacy until an approved phase replaces them; do not connect them to PixelLegends UI or report them as MOBA features.
- Do not add paid infrastructure, plugins, or dependencies without explaining the need and receiving approval.
- Keep all player-facing text and project documentation in English, as required by the current product direction.

## Work with the developer

The developer is a beginner. For implementation work, explain in simple terms what will change, why, which files are involved, how to run it, how to test it, what success looks like, and any limitations. Keep each step small and testable; do not silently omit important code or setup.

Run the available static checks after edits. Be explicit when Godot runtime, Android export, or device testing could not be performed; never report an unrun test as passed.
