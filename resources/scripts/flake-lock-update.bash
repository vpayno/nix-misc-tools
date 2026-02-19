# shellcheck shell=bash

usage() {
	{
		printf "Usage: %s [--list-inputs] [--include <input1,input2>] [--exclude <input3,input4>]\n" "${0}"
		printf "\n"
		printf "Valid flake inputs: %s\n" "${flake_inputs[*]}"
	} 1>&2
	exit 1
}

get_flake_inputs() {
	(
		nix repl <<-EOF
			:lf nixpkgs
			:lf .
			builtins.toString (builtins.attrNames inputs)
		EOF
	) 2>/dev/null | tr -d '"' | ansifilter | tr ' ' '\n' | sort -u | grep -E '^[a-zA-Z]'
}

declare option
declare -a flake_inputs=()
declare -a selected_inputs=()
declare -a excluded_inputs=()

mapfile -t flake_inputs < <(get_flake_inputs)

while getopts "li:e:h" option; do
	case "${option}" in
	l)
		get_flake_inputs
		exit
		;;
	i)
		mapfile -t selected_inputs < <(sed -r -e 's/,/\n/g' <<<"${OPTARG}")
		;;
	e)
		mapfile -t excluded_inputs < <(sed -r -e 's/,/\n/g' <<<"${OPTARG}")
		;;
	:)
		printf "ERROR: Option [%s] requires an argument\n" "-${OPTARG}" 1>&2
		usage
		;;
	h)
		usage
		;;
	*)
		usage
		;;
	esac
done
shift $((OPTIND - 1))

if [[ ${#selected_inputs[@]} -gt 0 && ${#excluded_inputs[@]} -gt 0 ]]; then
	printf "ERROR: -i and -e can't be used at the same time\n"
	usage
fi

declare -a inputs=()
declare valid
declare input_name

if [[ ${#selected_inputs[@]} -gt 0 ]]; then
	for item in "${selected_inputs[@]}"; do
		valid=false
		for input_name in "${flake_inputs[@]}"; do
			if [[ ${input_name} == "${item}" ]]; then
				valid=true
				break
			fi
		done
		if ! ${valid}; then
			{
				printf "ERROR: one or more selected inputs [%s] was not found in the flake inputs.\n" "${selected_inputs[@]}"
				printf "\n"
				printf "Valid flake inputs: %s\n" "${flake_inputs[*]}"
			} 1>&2
			exit 1
		fi
	done
	inputs=("${selected_inputs[@]}")
elif [[ ${#excluded_inputs[@]} -gt 0 ]]; then
	for item in "${excluded_inputs[@]}"; do
		valid=false
		for input_name in "${flake_inputs[@]}"; do
			if [[ ${input_name} == "${item}" ]]; then
				valid=true
				break
			fi
		done
		if ! ${valid}; then
			{
				printf "ERROR: one or more selected inputs [%s] was not found in the flake inputs.\n" "${excluded_inputs[@]}"
				printf "\n"
				printf "Valid flake inputs: %s\n" "${flake_inputs[*]}"
			} 1>&2
			exit 1
		fi
	done
	mapfile -t inputs < <(get_flake_inputs)
	declare -i i=0
	for ((i = 0; i < "${#inputs[@]}"; i++)); do
		for item in "${excluded_inputs[@]}"; do
			if [[ ${inputs[${i}]} == "${item}" ]]; then
				unset "inputs[${i}]"
				break
			fi
		done
	done
fi

declare gitmsgfile

gitmsgfile="$(mktemp)"

printf "\n"
printf "Updating flake lock file...\n"
printf "\n"

printf "nix: lock update\n\n" >"${gitmsgfile}"
if [[ ${#inputs[@]} -gt 0 ]]; then
	printf "\n"
	printf "Updating inputs: "
	printf "%s, " "${inputs[@]}" | sed -r -e 's/, $//g'
	printf "\n"
	printf "\n"
fi | tee -a "${gitmsgfile}"
nix flake update "${inputs[@]}" |& grep -v -E "^warning:" | tee -a "${gitmsgfile}" || true # keep grep from failing script when updates aren't found
printf "\n"

# success -> flake.lock not updated
# failure -> flake.lock updated
if git diff-files --quiet ./flake.lock; then
	printf "\n"
	printf "INFO: No updates for ./flake.lock found.\n"
	printf "\n"
else
	git commit --file "${gitmsgfile}" ./flake.lock
	printf "\n"
	printf "INFO: ./flake.lock updated.\n"
	printf "\n"
fi
