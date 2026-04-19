---
name: bootstrap-project
description: |
  Creates a new claude-to-code project from the five markdown files produced
  by the Spec Factory. Use whenever the user wants to start a new project
  from locked-in specs — phrases like "bootstrap a new project", "new
  project from specs", "set up claude-to-code project <name>", "create
  project <name>", "scaffold <name>", or similar. This skill handles:
  creating the GitHub repo from the template, cloning it locally, activating
  the pre-commit hook, placing the five markdown files in the correct
  locations, creating the initial working branch, and running validation.
  It is NOT a general-purpose project bootstrapper — it is specific to
  the claude-to-code template and pipeline.
---

# Bootstrap Project Skill

You are helping the operator bootstrap a new claude-to-code project. The
operator has just finished a Spec Factory session and has five markdown
files ready: `constitution.md`, `spec.md`, `plan.md`, `tasks.md`, and
`handoff-summary.md`.

## Steps

1. **Ensure the project name is explicit.**
   Never infer the project name from the operator's phrasing. Always ask:
   *"What's the project name? (used for the GitHub repo and the local
   folder — kebab-case recommended, e.g. `icoffee-v2`)"*

   Wait for the answer. Validate: lowercase letters, digits, hyphens only.
   If invalid, explain and ask again.

2. **Run the bootstrap script with the project name.**
   Execute `bash ~/.claude/skills/bootstrap-project/run.sh <project-name>`
   (adjust the path for Windows: use `%USERPROFILE%\.claude\skills\bootstrap-project\run.sh`
   under Git Bash, or the equivalent for your shell).

   The script handles everything else interactively:
   - Prompts for target folder (offering stored candidates)
   - Prompts for source folder where the 5 files live
   - Prompts for public/private
   - Creates the repo, clones it, configures hooks, places files,
     creates branch, commits, and reports status

3. **Relay script output to the operator faithfully.**
   The script is mostly self-explanatory. Do not add your own interpretation
   on top unless the operator asks questions.

4. **When the script finishes successfully, confirm next steps.**
   Tell the operator:
   - The project is ready at `<resolved path>`
   - The specs have been validated (A3 ran automatically as part of bootstrap)
   - They can now choose: `/ralph-go cautious` for autonomous execution, or
     interactive work in their IDE of choice

5. **If the script errors**, relay the error clearly and suggest the fix.
   Common errors and fixes:
   - `gh: not authenticated` → `gh auth login`
   - `file not found: constitution.md` → operator hasn't downloaded
     artifacts yet, or is pointing at the wrong folder
   - `project folder already exists` → pick a different name or delete the
     existing folder
