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

        usageMessagePre = ''
          Available ${name} flake commands:

            nix run .#usage | .#default              # this message
        '';

        showUsage = scripts.flake-usage-text;

        toolConfigs = pkgs.lib.mapAttrsToList (name: _: configs."${name}") configs;

        toolScripts = pkgs.lib.mapAttrsToList (name: _: scripts."${name}") scripts;

        configs = {
        };

        scripts = {
          currentSystem = pkgs.writeShellApplication {
            name = "current-system";
            runtimeInputs = with pkgs; [
              coreutils
            ];
            text = ''
              # we need the system variable to be replaced when script is built
              printf "%s" "${system}"
              [[ -t 1 ]] && printf "\n"
            '';
            meta = {
              description = "Returns the nix system (cpu-os) label";
            };
          };

          flakeLockUpdate = pkgs.writeShellApplication {
            name = "flake-lock-update";
            runtimeInputs = with pkgs; [
              coreutils
              git
              gnugrep
              gnupg
              nix
              openssh
            ];
            text = builtins.readFile ./resources/scripts/flake-lock-update.bash;
            meta = {
              description = "Updates flake.lock and creates the commit";
            };
          };

          flake-usage-text = pkgs.writeShellApplication {
            name = "flake-usage-text";
            runtimeInputs =
              with pkgs;
              [
                coreutils
                jq
                gnugrep
                nix
              ]
              ++ (with scripts; [
                current-system
              ]);
            text = ''
              declare json_text
              declare -a commands
              declare -a comments
              declare -i i

              printf "\n"
              printf "%s" "${usageMessagePre}"
              printf "\n"

              json_text="$(nix flake show --json 2>/dev/null | jq --sort-keys .)"

              mapfile -t commands < <(printf "%s" "$json_text" | jq -r --arg system "$(current-system)" '.apps[$system] | to_entries[] | select(.key | test("^(default|usage)$") | not) | "\("nix run .#")\(.key)"')
              mapfile -t comments < <(printf "%s" "$json_text" | jq -r --arg system "$(current-system)" '.apps[$system] | to_entries[] | select(.key | test("^(default|usage)$") | not) | "\("# ")\(.value.description)"')

              for ((i = 0; i < ''${#commands[@]}; i++)); do
                printf "  %-40s %s\n" "''${commands[$i]}" "''${comments[$i]}"
              done

              printf "\n"

              mapfile -t commands < <(printf "%s" "$json_text" | jq -r --arg system "$(current-system)" '.devShells[$system] | to_entries[] | "\("nix develop .#")\(.key)"')
              mapfile -t comments < <(printf "%s" "$json_text" | jq -r --arg system "$(current-system)" '.devShells[$system] | to_entries[] | "\("# ")\(.value.name)"')

              for ((i = 0; i < ''${#commands[@]}; i++)); do
                printf "  %-40s %s\n" "''${commands[$i]}" "''${comments[$i]}"
              done

              printf "\n"
            '';
            meta = {
              description = "Generate nix flake usage text";
            };
          };

          nixProfileDiffLatest = pkgs.writeShellApplication {
            name = "nix-profile-diff-latest";
            runtimeInputs = with pkgs; [
              coreutils
              findutils
              nix
              nvd
            ];
            text = builtins.readFile ./resources/scripts/nix-profile-diff-latest.bash;
            meta = {
              description = "Generates latest NixOS profile diff";
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

          currentSystem = scripts.currentSystem // {
            pname = "current-system";
            inherit version;
            name = "${self.packages.${system}.currentSystem.pname}-${
              self.packages.${system}.currentSystem.version
            }";
          };

          flakeLockUpdate = scripts.flakeLockUpdate // {
            pname = "flake-lock-update";
            inherit version;
            name = "${self.packages.${system}.flakeLockUpdate.pname}-${
              self.packages.${system}.flakeLockUpdate.version
            }";
          };

          nixProfileDiffLatest = scripts.nixProfileDiffLatest // {
            pname = "nix-profile-diff-latest";
            inherit version;
            name = "${self.packages.${system}.nixProfileDiffLatest.pname}-${
              self.packages.${system}.nixProfileDiffLatest.version
            }";
          };
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

          currentSystem = {
            type = "app";
            name = "${self.packages.${system}.currentSystem.pname}";
            inherit (self.packages.${system}.currentSystem) meta;
            program = "${pkgs.lib.getExe self.packages.${system}.currentSystem}";
          };

          flakeLockUpdate = {
            type = "app";
            name = "${self.packages.${system}.flakeLockUpdate.pname}";
            inherit (self.packages.${system}.flakeLockUpdate) meta;
            program = "${pkgs.lib.getExe self.packages.${system}.flakeLockUpdate}";
          };

          nixProfileDiffLatest = {
            type = "app";
            name = "${self.packages.${system}.nixProfileDiffLatest.pname}";
            inherit (self.packages.${system}.nixProfileDiffLatest) meta;
            program = "${pkgs.lib.getExe self.packages.${system}.nixProfileDiffLatest}";
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
