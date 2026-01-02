# shellcheck shell=bash

if [[ -z ''${1:-} || ''${1:-} == "." ]]; then
	printf "ERROR: You must pass an absolute path or git url to nix-inspect.\n"
	printf "\n"
	exit 1
fi 1>&2

{
	echo Running: nix-inspect --expr "\"builtins.getFlake \\\"$1\\\"\""
	printf "\n"
} 1>&2

exec nix-inspect --expr "builtins.getFlake \"$1\""
