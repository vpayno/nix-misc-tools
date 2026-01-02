# nix-misc-tools

Putting all of my miscellaneous tools in a single flake to make it easier to
reuse them.

## Usage

```text
$ nix run .#default

Available nix-misc-tools-20260101.0.0 flake commands:

  nix run .#flakeShowUsage | .#default     # this message

  nix run .#currentSystem                  # Returns the nix system (cpu-os) label
  nix run .#flakeLockUpdate                # Updates flake.lock and creates the commit
  nix run .#nixFlakeBrowser                # Nix flake terminal browser
  nix run .#nixProfileDiffLatest           # Generates latest NixOS profile diff

  nix develop .#default                    # nix-shell
```

## Tools

### current-system

Easy way to get the Nix `cpuarch`-`osname` label straight from Nix.

- local `nix run`

```text
$ nix run .#current-system
x86_64-linux
```

- remote `nix run`

```text
$ nix run github:vpayno/nix-misc-tools#current-system
x86_64-linux
```

- local `nix shell`

```text
$ nix shell

$ current-system
x86_64-linux

$ which current-system
/nix/store/74xxgj3sa1szcg136wnr4p3k3npsfckj-nix-misc-tools-20250925.0.0-bundle/bin/current-system
```

- remote `nix shell`

```text
$ nix shell github:vpayno/nix-misc-tools

$ current-system
x86_64-linux

$ which current-system
/nix/store/74xxgj3sa1szcg136wnr4p3k3npsfckj-nix-misc-tools-20250925.0.0-bundle/bin/current-system
```

- local `nix develop`

```text
$ nix develop
warning: Git tree '/home/vpayno/git_vpayno/nix-misc-tools' is dirty
 ______________________________________
/ Starting nix-misc-tools-20250925.0.0 \
|                                      |
\ nix develop .#default shell...       /
 --------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||

/nix/store/74xxgj3sa1szcg136wnr4p3k3npsfckj-nix-misc-tools-20250925.0.0-bundle
├── bin
│   └── current-system
└── etc

3 directories, 1 file
```

- remote `nix develop`

```text
$ nix develop github:vpayno/nix-misc-tools
 ______________________________________
/ Starting nix-misc-tools-20250925.0.0 \
|                                      |
\ nix develop .#default shell...       /
 --------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||

/nix/store/74xxgj3sa1szcg136wnr4p3k3npsfckj-nix-misc-tools-20250925.0.0-bundle
├── bin
│   └── current-system
└── etc

3 directories, 1 file
```
