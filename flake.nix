{
  description = "Shared coding agent configuration for Niteo";

  inputs = {
    mcp-nixos.url = "github:utensils/mcp-nixos";
  };

  outputs =
    { self, mcp-nixos }:
    {
      lib = {

        rules =
          let
            files = builtins.attrNames (builtins.readDir ./rules);
            mdFiles = builtins.filter (name: builtins.match ".*\\.md" name != null) files;
          in
          builtins.listToAttrs (
            builtins.map (name: {
              name = builtins.replaceStrings [ ".md" ] [ "" ] name;
              value = builtins.readFile (./rules + "/${name}");
            }) mdFiles
          );

        skills =
          let
            skillDirs = builtins.attrNames (builtins.readDir ./skills);
          in
          builtins.listToAttrs (
            builtins.map (name: {
              inherit name;
              value = ./skills + "/${name}";
            }) skillDirs
          );

        mcpPackages =
          pkgs:
          let
            fastmcp = pkgs.python3Packages.callPackage ./pkgs/by-name/fa/fastmcp/package.nix { };

            # ultralytics' test_data_utils downloads a dataset that upstream
            # deleted (HTTP 404). Sandboxed builds skip it as offline, but
            # builds with network access (e.g. darwin with sandbox=false) run
            # it and fail. Fixed upstream in ultralytics 8.4.62; drop this
            # override once nixpkgs ships that or newer.
            ultralytics = pkgs.python3Packages.ultralytics.overridePythonAttrs (old: {
              disabledTests = (old.disabledTests or [ ]) ++ [ "test_data_utils" ];
            });
          in
          {
            help-scout-mcp-server = pkgs.callPackage ./pkgs/by-name/he/help-scout-mcp-server/package.nix { };
            inherit fastmcp;
            imagesorcery-mcp = pkgs.python3Packages.callPackage ./pkgs/by-name/im/imagesorcery-mcp/package.nix {
              inherit fastmcp ultralytics;
            };
          };

        mcpServers = pkgs: {

          cloudflare-docs = {
            type = "http";
            url = "https://docs.mcp.cloudflare.com/mcp";
          };

          # Login with `heroku login`
          heroku = {
            command = "${pkgs.heroku}/bin/heroku";
            args = [ "mcp:start" ];
            env = {
              PATH = "${pkgs.nodejs}/bin:${pkgs.heroku}/bin";
            };
          };

          # Token is created on https://niteo.grafana.net/org/serviceaccounts
          # and is saved in 1Password
          mcp-grafana = {
            command = "${pkgs.mcp-grafana}/bin/mcp-grafana";
            env = {
              GRAFANA_URL = "https://niteo.grafana.net";
              GRAFANA_SERVICE_ACCOUNT_TOKEN = "\${GRAFANA_SERVICE_ACCOUNT_TOKEN}";
            };
          };

          mcp-nixos = {
            command = "${mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/mcp-nixos";
          };

          # export PROMETHEUS_AUTH="$(echo -n 'grafana:<PASSWORD_FROM_1P>' | base64)"
          prometheus = {
            type = "http";
            url = "https://prometheus.niteo.co/mcp/";
            headers = {
              Authorization = "Basic \${PROMETHEUS_AUTH}";
            };
          };

          customerio = {
            type = "http";
            url = "https://mcp-eu.customer.io/mcp";
          };

          # Browser-based OAuth: log in from `/mcp` (Claude Code) or `codex mcp login sentry`
          sentry = {
            type = "http";
            url = "https://mcp.sentry.dev/mcp";
          };

          imagesorcery-mcp = {
            command = "${(self.lib.mcpPackages pkgs).imagesorcery-mcp}/bin/imagesorcery-mcp";
          };

          # Requires HELPSCOUT_APP_ID and HELPSCOUT_APP_SECRET in environment
          # Get credentials from Help Scout → Your Profile → My Apps -> Create App
          # Name it "Claude MCP", the URL can be anything (e.g. https://niteo.co)
          help-scout = {
            command = "${(self.lib.mcpPackages pkgs).help-scout-mcp-server}/bin/help-scout-mcp-server";
          };
        };

        # Codex reads the same servers from config.toml, but with different keys and -
        # crucially - no `${VAR}` expansion anywhere. Translate mechanically:
        #   * `type` is dropped; codex infers stdio vs http from `command` / `url`
        #   * `headers` becomes `http_headers`
        #   * an env value that is a bare `${VAR}` becomes `env_vars`, codex's
        #     whitelist for forwarding a shell variable
        toCodexMcp =
          pkgs:
          let
            inherit (pkgs) lib;

            placeholderVar =
              v:
              let
                m = if builtins.isString v then builtins.match "[$][{]([A-Za-z_][A-Za-z_0-9]*)[}]" v else null;
              in
              if m == null then null else builtins.head m;

            convert =
              server:
              let
                env = server.env or { };
                forwarded = lib.filterAttrs (_: v: placeholderVar v != null) env;
                literal = builtins.removeAttrs env (builtins.attrNames forwarded);
              in
              builtins.removeAttrs server [
                "type"
                "env"
                "headers"
              ]
              // lib.optionalAttrs (literal != { }) { env = literal; }
              // lib.optionalAttrs (forwarded != { }) {
                env_vars = lib.mapAttrsToList (_: placeholderVar) forwarded;
              }
              // lib.optionalAttrs (server ? headers) { http_headers = server.headers; };
          in
          lib.mapAttrs (_: convert);

        # The team's servers for codex. `Basic ${PROMETHEUS_AUTH}` cannot survive the
        # translation: codex never expands headers, and `bearer_token_env_var`
        # hardcodes a `Bearer` scheme. `http_headers_helper` runs a command that
        # prints the headers as JSON instead. It sources `secretsFile`, the shell
        # file that sets PROMETHEUS_AUTH, rather than trusting the helper to
        # inherit the shell environment: codex scrubs some vars from children.
        codexMcpServers =
          pkgs:
          { secretsFile }:
          let
            translated = self.lib.toCodexMcp pkgs (self.lib.mcpServers pkgs);
            prometheusAuthHelper = pkgs.writeShellScript "codex-prometheus-auth" ''
              . "${secretsFile}"
              printf '{"Authorization":"Basic %s"}' "$PROMETHEUS_AUTH"
            '';
          in
          translated
          // {
            prometheus = builtins.removeAttrs translated.prometheus [ "http_headers" ] // {
              http_headers_helper = toString prometheusAuthHelper;
            };
          };

      };
    };
}
