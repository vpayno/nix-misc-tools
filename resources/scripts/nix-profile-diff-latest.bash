# shellcheck shell=bash

nixos_diff() {
	if [[ ! -d /nix/var/nix/profiles/system ]]; then
		return 0
	fi

	local -a nix_links

	mapfile -t nix_links < <(find /nix/var/nix/profiles/ -type l -regextype posix-extended -regex '^.*/system-[0-9]+-link$' | sort -V | tail -n 2)
	if [[ ${#nix_links[@]} -eq 2 ]]; then
		printf "\n"
		printf "Generating latest nixos profile diff...\n"
		printf "\n"
		nvd diff "${nix_links[@]}"
		printf "\n"
	else
		{
			printf "\n"
			printf "Not enough nixos generations found for a diff.\n"
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
