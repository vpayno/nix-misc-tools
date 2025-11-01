# flake.nix
{
  description = "My miscelaneous tools wrapped in a Nix Flake";

  inputs = {
    nixpkgs.url = "github:nixOS/nixpkgs/nixos-unstable";

    systems.url = "github:vpayno/nix-systems-default";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    treefmt-conf = {
      url = "github:vpayno/nix-treefmt-conf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      treefmt-conf,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pname = "nix-misc-tools";
        version = "20250925.0.0";
        name = "${pname}-${version}";

        flake_repo_url = "github:vpayno/nix-misc-tools";

        pkgs = nixpkgs.legacyPackages.${system};

        metadata = {
          homepage = "https://github.com/vpayno/nix-misc-tools";
          description = "My miscelaneous tools wrapped in a Nix Flake";
          license = with pkgs.lib.licenses; [ mit ];
          # maintainers = with pkgs.lib.maintainers; [vpayno];
          maintainers = [
            {
              email = "vpayno@users.noreply.github.com";
              github = "vpayno";
              githubId = 3181575;
              name = "Victor Payno";
            }
          ];
          mainProgram = "showUsage";
        };

        usageMessage = ''
          Available ${name} flake commands:

            nix run .#usage | .#default        # this message
            nix run .#current-system           # returns nix cpuarch-osname label
            nix run .#flake-lock-update        # updates flake.lock and creates the commit

            nix develop .#default
        '';

        # very odd, this doesn't work with pkgs.writeShellApplication
        # odd quoting error when the string usagemessage as new lines
        showUsage = pkgs.writeShellScriptBin "showUsage" ''
          printf "%s" "${usageMessage}"
        '';

        toolConfigs = pkgs.lib.mapAttrsToList (name: _: scripts."${name}") configs;

        toolScripts = pkgs.lib.mapAttrsToList (name: _: scripts."${name}") scripts;

        configs = {
        };

        scripts = {
          current-system = pkgs.writeShellApplication {
            name = "current-system";
            runtimeInputs = with pkgs; [
              coreutils
            ];
            text = ''
              printf "%s" "${system}"
              [[ -t 1 ]] && printf "\n"
            '';
            meta = {
              description = "returns the nix system label";
            };
          };
          flake-lock-update = pkgs.writeShellApplication {
            name = "flake-lock-update";
            runtimeInputs = with pkgs; [
              coreutils
              git
              gnugrep
              gnupg
              nix
            ];
            text = ''
              gitmsgfile="$(mktemp)"
              { printf "nix: lock update\n\n"; nix flake update; } |& grep -v -E "^warning:" | tee "$gitmsgfile"
              printf "\n"
              git commit --file "$gitmsgfile" ./flake.lock
            '';
            meta = {
              description = "Updates flake.lock";
            };
          };
        };

        toolBundle = pkgs.buildEnv {
          name = "${name}-bundle";
          paths = toolScripts;
          buildInputs = with pkgs; [
            makeWrapper
          ];
          pathsToLink = [
            "/bin"
            "/etc"
          ];
          postBuild = ''
            extra_bin_paths="${pkgs.lib.makeBinPath toolScripts}"
            printf "Adding extra bin paths to wrapper scripts: %s\n" "$extra_bin_paths"
            printf "\n"

            for p in "$out"/bin/*; do
              if [[ ! -x $p ]]; then
                continue
              fi
              echo wrapProgram "$p" --set PATH "$extra_bin_paths"
              wrapProgram "$p" --set PATH "$extra_bin_paths"
            done
          '';
        };
      in
      {
        formatter = treefmt-conf.formatter.${system};

        packages = {
          default = toolBundle;

          inherit (scripts) current-system;
          inherit (scripts) flake-lock-update;
        };

        apps = rec {
          default = usage;

          usage = {
            type = "app";
            pname = "usage";
            inherit version;
            name = "${pname}-${version}";
            program = "${pkgs.lib.getExe showUsage}";
            meta = metadata;
          };

          current-system = {
            type = "app";
            name = "current-system";
            inherit (self.packages.${system}.current-system) meta;
            program = "${nixpkgs.lib.getExe self.packages.${system}.current-system}";
          };

          flake-lock-update = {
            type = "app";
            name = "flake-lock-update";
            inherit (self.packages.${system}.flake-lock-update) meta;
            program = "${nixpkgs.lib.getExe self.packages.${system}.flake-lock-update}";
          };
        };

        devShells = {
          default = pkgs.mkShell rec {
            packages = with pkgs; [
              bashInteractive
              toolBundle
            ];

            shellMotd = ''
              Starting ${name}

              nix develop .#default shell...
            '';

            shellHook = ''
              ${pkgs.lib.getExe pkgs.cowsay} "${shellMotd}"
              printf "\n"

              ${pkgs.lib.getExe pkgs.tree} "${toolBundle}"
              printf "\n"
            '';
          };
        };
      }
    );
}
