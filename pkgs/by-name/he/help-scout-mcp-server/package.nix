{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "help-scout-mcp-server";
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "drewburchfield";
    repo = "help-scout-mcp-server";
    rev = "v${version}";
    hash = "sha256-GR7i3s3u2dqMft2HrZExSN5+lOY/cgq1puJlJ0lOWf8=";
  };

  npmDepsHash = "sha256-ibUlE7jwrYd/sD54wd/pqFjyIyjY85WWAH/P29BoTH0=";

  meta = {
    description = "Help Scout MCP server";
    homepage = "https://github.com/drewburchfield/help-scout-mcp-server";
    license = lib.licenses.mit;
    mainProgram = "help-scout-mcp-server";
    platforms = lib.platforms.all;
  };
}
