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

    home-manager = {
      url = "github:nix-community/home-manager";
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
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pname = "nix-misc-tools";
        version = "20260101.0.1";
        name = "${pname}-${version}";

        flake_repo_url = "github:vpayno/nix-misc-tools";

        pkgs = nixpkgs.legacyPackages.${system};

        flakeMetaData = {
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
          mainProgram = "flake-show-usage";
        };

        usageMessagePre = ''
          Available ${name} flake commands:

            nix run .#flakeShowUsage | .#default     # this message
        '';

        toolConfigs = pkgs.lib.mapAttrsToList (name: _: configs."${name}") configs;

        toolScripts = pkgs.lib.mapAttrsToList (name: _: scripts."${name}") scripts;

        generatePackagesFromScripts = pkgs.lib.mapAttrs (
          name: _:
          scripts."${name}"
          // {
            inherit (scriptMetadata."${name}") pname;
            inherit version;
            name = "${self.packages.${system}."${name}".pname}-${self.packages.${system}."${name}".version}";
          }
        ) scripts;

        generateAppsFromScripts = pkgs.lib.mapAttrs (
          name: _:
          scripts."${name}"
          // {
            type = "app";
            name = "${self.packages.${system}.${name}.pname}";
            inherit (self.packages.${system}.${name}) meta;
            program = "${pkgs.lib.getExe self.packages.${system}.${name}}";
          }
        ) scripts;

        configs = {
        };

        scriptMetadata = {
          flakeShowUsage = rec {
            pname = "flake-show-usage";
            inherit version;
            name = "${pname}-${version}";
            description = "Show Nix flake usage text";
          };

          currentSystem = rec {
            pname = "current-system";
            inherit version;
            name = "${pname}-${version}";
            description = "Returns the nix system (cpu-os) label";
          };

          flakeLockUpdate = rec {
            pname = "flake-lock-update";
            inherit version;
            name = "${pname}-${version}";
            description = "Updates flake.lock and creates the commit";
          };

          nixProfileDiffLatest = rec {
            pname = "nix-profile-diff-latest";
            inherit version;
            name = "${pname}-${version}";
            description = "Generates latest NixOS profile diff";
          };

          nixFlakeBrowser = rec {
            pname = "flake-browser";
            inherit version;
            name = "${pname}-${version}";
            description = "Nix flake terminal browser";
          };
        };

        scripts = {
          flakeShowUsage = pkgs.writeShellApplication {
            name = scriptMetadata.flakeShowUsage.pname;
            runtimeInputs = with pkgs; [
              coreutils
              jq
              gnugrep
              nix
            ];
            text = ''
              declare json_text
              declare -a commands
              declare -a comments
              declare -i i

              printf "\n"
              printf "%s" "${usageMessagePre}"
              printf "\n"

              json_text="$(nix flake show --json 2>/dev/null | jq --sort-keys .)"

              mapfile -t commands < <(printf "%s" "$json_text" | jq -r --arg system "${system}" '.apps[$system] | to_entries[] | select(.key | test("^(default|flakeShowUsage)$") | not) | "\("nix run .#")\(.key)"')
              mapfile -t comments < <(printf "%s" "$json_text" | jq -r --arg system "${system}" '.apps[$system] | to_entries[] | select(.key | test("^(default|flakeShowUsage)$") | not) | "\("# ")\(.value.description)"')

              for ((i = 0; i < ''${#commands[@]}; i++)); do
                printf "  %-40s %s\n" "''${commands[$i]}" "''${comments[$i]}"
              done

              printf "\n"

              mapfile -t commands < <(printf "%s" "$json_text" | jq -r --arg system "${system}" '.devShells[$system] | to_entries[] | "\("nix develop .#")\(.key)"')
              mapfile -t comments < <(printf "%s" "$json_text" | jq -r --arg system "${system}" '.devShells[$system] | to_entries[] | "\("# ")\(.value.name)"')

              for ((i = 0; i < ''${#commands[@]}; i++)); do
                printf "  %-40s %s\n" "''${commands[$i]}" "''${comments[$i]}"
              done

              printf "\n"
            '';
            meta = scriptMetadata.flakeShowUsage;
          };

          currentSystem = pkgs.writeShellApplication {
            name = scriptMetadata.currentSystem.pname;
            runtimeInputs = with pkgs; [
              coreutils
            ];
            text = ''
              # we need the system variable to be replaced when script is built
              printf "%s" "${system}"
              [[ -t 1 ]] && printf "\n"
            '';
            meta = scriptMetadata.currentSystem;
          };

          flakeLockUpdate = pkgs.writeShellApplication {
            name = scriptMetadata.flakeLockUpdate.pname;
            runtimeInputs = with pkgs; [
              coreutils
              git
              gnugrep
              gnupg
              nix
            ];
            text = builtins.readFile ./resources/scripts/flake-lock-update.bash;
            meta = scriptMetadata.flakeLockUpdate;
          };

          nixProfileDiffLatest = pkgs.writeShellApplication {
            name = scriptMetadata.nixProfileDiffLatest.pname;
            runtimeInputs =
              with pkgs;
              [
                coreutils
                findutils
                gawk
                nix
                nvd
              ]
              ++ [
                inputs.home-manager.packages.${system}.default
              ];
            text = builtins.readFile ./resources/scripts/nix-profile-diff-latest.bash;
            meta = scriptMetadata.nixProfileDiffLatest;
          };

          nixFlakeBrowser = pkgs.writeShellApplication {
            name = scriptMetadata.nixFlakeBrowser.pname;
            runtimeInputs = with pkgs; [
              coreutils
              nix-inspect
            ];
            text = builtins.readFile ./resources/scripts/flake-browser.bash;
            meta = scriptMetadata.nixFlakeBrowser;
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
              if [[ $p =~ /flake-show-usage$ ]]; then
                rm -fv $p
                continue
              fi
              # echo wrapProgram "$p" --set PATH "$extra_bin_paths"
              # wrapProgram "$p" --set PATH "$extra_bin_paths"
            done
          '';
        };
      in
      {
        formatter = treefmt-conf.formatter.${system};

        packages = {
          default = toolBundle;
        }
        // generatePackagesFromScripts;

        apps = {
          default = self.apps.${system}.flakeShowUsage;
        }
        // generateAppsFromScripts;

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
