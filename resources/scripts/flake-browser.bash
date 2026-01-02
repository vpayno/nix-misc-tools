# shellcheck shell=bash

declare flake_uri="${1:-}"

if [[ -z ${flake_uri} ]]; then
	printf "ERROR: You must pass an absolute path or git url to nix-inspect.\n"
	printf "\n"
	exit 1
fi 1>&2

if [[ ${flake_uri} == . ]]; then
	flake_uri="${PWD}"
fi

{
	echo Running: nix-inspect --expr "\"builtins.getFlake \\\"${flake_uri}\\\"\""
	printf "\n"
} 1>&2

exec nix-inspect --expr "builtins.getFlake \"${flake_uri}\""
