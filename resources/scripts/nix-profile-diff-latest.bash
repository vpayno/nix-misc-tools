# shellcheck shell=bash

nixos_diff() {
	if [[ ! -d /nix/var/nix/profiles/system ]]; then
		printf "\n"
		printf "ERROR: No NixOS system profiles found under /nix/var/nix/profiles/\n"
		printf "\n"
		return
	fi

	declare -a nix_links
	mapfile -t nix_links < <(find /nix/var/nix/profiles/ -type l -regextype posix-extended -regex '^.*/system-[0-9]+-link$' | sort -V | tail -n 2)
	if [[ ${#nix_links[@]} -eq 2 ]]; then
		printf "\n"
		printf "Generating latest nixos profile diff...\n"
		printf "\n"
		nvd diff "${nix_links[@]}"
		printf "\n"
	else
		printf "Not enough nixos generations found for a diff.\n"
	fi
}

hm_diff() {
	if ! command -v home-manager >&/dev/null; then
		printf "\n"
		printf "ERROR: home-manager not found\n"
		printf "\n"
		return
	fi

	declare -a hm_links
	mapfile -t hm_links < <(home-manager generations | awk '/ id [0-9]+ / { print $7 }' | head -n 2 | tac)
	if [[ ${#hm_links[@]} -eq 2 ]]; then
		printf "\n"
		printf "Generating latest home-manager profile diff...\n"
		printf "\n"
		nvd diff "${hm_links[@]}"
		printf "\n"
	else
		printf "Not enough home-manager generations found for a diff.\n"
	fi
}

main() {
	nixos_diff
	hm_diff
}

main
