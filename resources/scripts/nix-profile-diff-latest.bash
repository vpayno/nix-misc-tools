# shellcheck shell=bash

get_nix_os_name() {
	if command -v nixos-rebuild >&/dev/null; then
		printf "%s" "NixOS"
	elif command -v darwin-rebuild >&/dev/null; then
		printf "%s" "nix-darwin"
	elif command -v system-manager >&/dev/null; then
		printf "%s" "system-manager"
	else
		printf "%s" "unknown_os"
	fi
}

nixos_diff() {
	if [[ ! -d /nix/var/nix/profiles/system ]]; then
		return 0
	fi

	local -a nix_links

	mapfile -t nix_links < <(find /nix/var/nix/profiles/ -type l -regextype posix-extended -regex '^.*/system-[0-9]+-link$' | sort -V | tail -n 2)
	if [[ ${#nix_links[@]} -eq 2 ]]; then
		printf "\n"
		printf "Generating latest %s profile diff...\n" "$(get_nix_os_name)"
		printf "\n"
		nvd diff "${nix_links[@]}"
		printf "\n"
	else
		{
			printf "\n"
			printf "Not enough %s generations found for a diff.\n" "$(get_nix_os_name)"
			printf "\n"
		} 1>&2
		return 1
	fi
}

sysmgr_diff() {
	if [[ ! -d /nix/var/nix/profiles/system-manager-profiles ]]; then
		return 0
	fi

	local -a sm_links

	mapfile -t nix_links < <(find /nix/var/nix/profiles/system-manager-profiles/ -type l -regextype posix-extended -regex '^.*/system-manager-[0-9]+-link$' | sort -V | tail -n 2)
	if [[ ${#sm_links[@]} -eq 2 ]]; then
		printf "\n"
		printf "Generating latest %s profile diff...\n" "$(get_nix_os_name)"
		printf "\n"
		nvd diff "${sm_links[@]}"
		printf "\n"
	else
		{
			printf "\n"
			printf "Not enough %s generations found for a diff.\n" "$(get_nix_os_name)"
			printf "\n"
		} 1>&2
		return 1
	fi
}

hm_diff() {
	if ! command -v home-manager >&/dev/null; then
		return 0
	fi

	local -a hm_links

	mapfile -t hm_links < <(home-manager generations | awk '/ id [0-9]+ / { print $7 }' | head -n 2 | tac)
	if [[ ${#hm_links[@]} -eq 2 ]]; then
		printf "\n"
		printf "Generating latest home-manager profile diff...\n"
		printf "\n"
		nvd diff "${hm_links[@]}"
		printf "\n"
	else
		return 0
	fi
}

main() {
	local -i retval=0

	nixos_diff || ((retval += 1))
	sysmgr_diff || ((retval += 1))
	hm_diff || ((retval += 1))

	if [[ ${retval} -gt 0 ]]; then
		{
			printf "\n"
			printf "ERROR: One or more errors encountered. (count: %d)\n" ${retval} 1>&2
			printf "\n"
		} 1>&2
		exit 1
	fi
}

main
