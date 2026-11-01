# Niteo agents

Coding agent configuration shared across all Niteo projects and all Niteans: rules, skills and MCP servers. Claude Code and Codex both use it.

## Projects

Projects use `rules/` from this repo in their work folders to tell agents how our code looks like, what conventions to follow, and what commands are available.

Any project-specific instructions are added to the project's own `AGENTS.md`.

### Example

Projects pin this repo as a flake input and symlink `rules/` and `skills/` into `.agents/` from their devShell, with a committed `.claude -> .agents` symlink. Codex reads skills from `.agents/skills/` natively; Claude Code reads skills and rules only under `.claude/`, which the symlink covers.

1. Add this repo as a flake input (`nix/flake.nix`):

   ```nix
   inputs.niteo-agents.url = "github:teamniteo/agents";
   ```

2. Fetch it as a source (`nix/default.nix`):

   ```nix
   niteoAgentsNode = flakeLock.nodes.${flakeLock.nodes.root.inputs.niteo-agents};

   flakeSources.niteo-agents = builtins.fetchTarball {
     url = "https://github.com/teamniteo/agents/archive/${niteoAgentsNode.locked.rev}.tar.gz";
     sha256 = niteoAgentsNode.locked.narHash;
   };
   ```

3. Symlink `rules/` and `skills/` into `.agents/` from the devShell's `shellHook`:

   ```nix
   shellHook = ''
     mkdir -p "$PROJECT_ROOT/.agents"
     ln -sfn ${pkgs.flakeSources.niteo-agents}/rules  "$PROJECT_ROOT/.agents/rules"
     ln -sfn ${pkgs.flakeSources.niteo-agents}/skills "$PROJECT_ROOT/.agents/skills"
   '';
   ```

   Then commit the symlink once with `ln -s .agents .claude`, and gitignore `.agents/*` (un-ignoring any committed `.agents/skills-local/`).

4. Reference the shared rules from the project's `AGENTS.md`:

   ```markdown
   Make sure to use common @.agents/rules/tooling.md and follow the
   @.agents/rules/conventions.md when working in this repo.
   ```

   Claude Code reads `AGENTS.md` when the project has no `CLAUDE.md`; Codex always does.

Bump the shared config project-wide with `nix flake update niteo-agents`.

### Rules for agents without `rules/`

Claude Code loads a rule by itself, always or when a file matching its `paths:` frontmatter is touched. The frontmatter has to open the file, so the "Managed in" comment sits below it. Codex has no rules directory, so:

- each path-scoped rule has a matching `*-rules` skill that points at it, which Codex picks by its description;
- `conventions.md` and `tooling.md` apply everywhere, so Niteans put them in Codex's global `~/.codex/AGENTS.md` from home-manager (`niteo-agents.lib.rules`).

Edit the rule, never the skill: the skill holds no content of its own.

## Niteans

Niteans use skills, MCPs and the shared rules from this repo in their home-manager setup of Claude Code and Codex, so that both gain Niteo-specific capabilities.

Claude Code takes `lib.mcpServers` as is. Codex reads the same servers with different keys and no `${VAR}` expansion, so take them from `lib.codexMcpServers pkgs { secretsFile = ...; }`, where `secretsFile` is the shell file that sets `PROMETHEUS_AUTH`. `lib.toCodexMcp pkgs` translates personal servers the same way.

Codex reads a project's `AGENTS.md`, and so the project's instructions, only once the project is trusted, and it matches trust by exact path: the checkout itself or its git root, never a parent folder like `~/work`. List every checkout you use under `projects` in your Codex settings, each with `trust_level = "trusted"`. A home-manager `config.toml` is read-only, so Codex cannot save the trust you give it when it asks.

Niteans are free to expand with their personal tooling or preferences, and are encouraged to generalize and contribute back to this repo for other Niteans to benefit.


# Convention

## Skills instead of Commands

Commands were merged into [Skills](https://code.claude.com/docs/en/skills) in v2.1.3. Let's use Skills from now on.

https://www.reddit.com/r/ClaudeAI/comments/1q92wwv/merged_commands_and_skills_in_213_update/

## No need for Plugins

Because we use HomeManager to manage Claude Code, we don't need to use [Plugins](https://code.claude.com/docs/en/plugins).



TODO:
* Keep SKILL.md under 500 lines for optimal performance. If your content exceeds this, split detailed reference material into separate files.
* https://code.claude.com/docs/en/hooks-guide#custom-notification-hook
* Query production databases: heroku config | grep DATABASE_READONLY_URL to get connection string, then claude mcp add --transport stdio db -- npx -y @bytebase/dbhub \
  --dsn "<connection string>"
* https://code.claude.com/docs/en/sandboxing
* Privacy settings can be changed at any time at claude.ai/settings/data-privacy-controls.
* https://code.claude.com/docs/en/settings -> companyAnnouncements
* https://code.claude.com/docs/en/settings#attribution-settings
* https://code.claude.com/docs/en/statusline
* forceLoginMethod
* https://code.claude.com/docs/en/memory#claude-md-imports
* https://github.com/roman/mcps.nix
* https://github.com/anthropics/claude-plugins-official/blob/main/plugins/code-simplifier/agents/code-simplifier.md
* https://github.com/anthropics/claude-plugins-official/tree/main/plugins/commit-commands/commands
* slack mcp
* agentsDir = "${claude-plugins}/plugins/code-simplifier/agents";