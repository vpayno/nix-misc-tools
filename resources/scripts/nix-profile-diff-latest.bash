# shellcheck shell=bash

if [[ ! -d /nix/var/nix/profiles/system ]]; then
	printf "\n"
	printf "ERROR: No NixOS system profiles found under /nix/var/nix/profiles/\n"
	printf "\n"
	exit 1
fi

printf "\n"
printf "Generating latest nixos profile diff...\n"
printf "\n"

# shellcheck disable=SC2046
nvd diff $(find /nix/var/nix/profiles/ -type l -regextype posix-extended -regex '^.*/system-[0-9]+-link$' | sort -V | tail -n 2 | tr "\n" " ")
printf "\n"
