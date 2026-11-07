<!-- Managed in https://github.com/teamniteo/agents — edit there, not here.
     If you have project-specific instructions to add, README.md is the best place. -->

# Tooling

## GitHub

Use the `gh` CLI for all GitHub operations — reading PRs and issues, fetching diffs, reading file contents from remote repos, and posting comments. It is already authenticated. Prefer `gh` (and `gh api` for anything not covered by a subcommand) over hitting the GitHub REST API by hand.

## MCP Servers

- **Cloudflare Docs**: Provides up-to-date Cloudflare documentation.
- **Grafana**: Requires `GRAFANA_SERVICE_ACCOUNT_TOKEN` environment variable from 1Password.
- **Heroku**: Uses existing Heroku CLI authentication. If unauthenticated, ask the user to run `heroku login`. Get the project's Heroku app name from README.md.
- **ImageSorcery**: Local image manipulation (crop, blur, optimize).
- **Customer.io**: Browser-based OAuth. Use for email campaigns, segments, templates, and workspace data.
- **NixOS (mcp-nixos)**: Query NixOS packages, options, Home Manager, Darwin, and flake information.
- **Prometheus**:
    1. Requires `PROMETHEUS_AUTH` environment variable. Get the password from 1Password then run `export PROMETHEUS_AUTH="$(echo -n 'grafana:<PASSWORD>' | base64)"`.
    2. Requires Niteo VPN connection. If the Prometheus MCP fails to connect, ask the user to connect to the Niteo VPN.
- **Sentry**: Browser-based OAuth. Use for error monitoring, issue analysis, and root cause investigation.

## Image Manipulation

Use the imagesorcery MCP server for any image manipulation tasks.

When a user is working on an image, offer to help with the following tasks:
- Crop to specific size while focusing on the important part of the image.
- Bluring out sensitive information.
- Optimizing images for faster loading times.

## Sandboxes

Every Nitean has a disposable Linux x86_64 sandbox, reached with `ssh sandbox-<username>`. Propose it, and wait for the user to agree, then run the work over SSH from here, when:

- A task needs to run for hours or would tie up the user's laptop.
- A build or tool fails for a Mac-specific reason and would work on Linux.

Use Passlet for all GitHub access inside the sandbox. If the sandbox isn't paired yet, tell the user to expect a Touch ID prompt, run `passlet approver pair` on their Mac, and inside the sandbox run the `passlet pair` command it prints with `unix:///home/<username>/.local/share/passlet/passlet.sock` as the endpoint, keeping the code out of your output.

Start long tasks with `nohup`, write output to a log file, and check back on the log. Request all the GitHub access a task needs before starting it, because new grants need an open SSH connection. If `ssh` hangs or `passlet doctor` can't connect, run `ssh -O exit sandbox-<username>` and retry. Treat everything in a sandbox as temporary. For setup and limits, see the sandbox docs in the teamniteo/servers repo.
