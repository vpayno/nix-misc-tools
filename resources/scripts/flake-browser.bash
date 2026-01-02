# shellcheck shell=bash

declare arg="''${1:-}"

if [[ -z $arg ]]; then
	printf "ERROR: You must pass an absolute path or git url to nix-inspect.\n"
	printf "\n"
	exit 1
fi 1>&2

if [[ "$arg" == "." ]]; then
	arg="$PWD"
fi

{
	echo Running: nix-inspect --expr "\"builtins.getFlake \\\"$arg\\\"\""
	printf "\n"
} 1>&2

exec nix-inspect --expr "builtins.getFlake \"$arg\""
