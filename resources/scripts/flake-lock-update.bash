# shellcheck shell=bash

declare -a args=("${@}")

gitmsgfile="$(mktemp)"

printf "\n"
printf "Updating flake lock file...\n"
printf "\n"

printf "nix: lock update\n\n" >"$gitmsgfile"
if [[ ${#args[@]} -gt 0 ]]; then
	printf "\n"
	printf "Updating inputs: "
	printf "%s, " "${args[@]}" | sed -r -e 's/, $//g'
	printf "\n"
	printf "\n"
fi | tee -a "$gitmsgfile"
nix flake update "${args[@]}" |& grep -v -E "^warning:" | tee -a "$gitmsgfile" || true # keep grep from failing script when updates aren't found
printf "\n"

# success -> flake.lock not updated
# failure -> flake.lock updated
if git diff-files --quiet ./flake.lock; then
	printf "\n"
	printf "INFO: No updates for ./flake.lock found.\n"
	printf "\n"
else
	git commit --file "$gitmsgfile" ./flake.lock
	printf "\n"
	printf "INFO: ./flake.lock updated.\n"
	printf "\n"
fi
