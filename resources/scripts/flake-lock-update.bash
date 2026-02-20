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

is_in_array() {
	local -n data="${1}"
	local -n keys="${2}"

	local valid
	local item
	local input_name

	for item in "${keys[@]}"; do
		valid=false
		for input_name in "${data[@]}"; do
			if [[ ${input_name} == "${item}" ]]; then
				valid=true
				break
			fi
		done
	done

	"${valid}"
}

invalid_input_msg() {
	local -n flake_data="${1}"
	local -n selected_data="${2}"
	local mode="${3}"

	{
		if [[ ${#selected_data[@]} -eq 1 ]]; then
			printf "ERROR: %s input [%s] wasn't found in the flake inputs.\n" "${mode}" "${selected_data[@]}"
		else
			printf "ERROR: one or more %s inputs [%s] weren't found in the flake inputs.\n" "${mode}" "${selected_data[@]}"
		fi
		printf "\n"
		printf "Valid flake inputs: %s\n" "${flake_data[*]}"
	} 1>&2
}

reduce_list() {
	local -n data="${1}"
	local -n keys="${2}"

	local -i i=0
	local item

	for item in "${excluded_inputs[@]}"; do
		for ((i = 0; i < "${#inputs[@]}"; i++)); do
			if [[ ${inputs[${i}]} == "${item}" ]]; then
				unset "inputs[${i}]"
				break
			fi
		done
	done
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
	if ! is_in_array flake_inputs selected_inputs; then
		invalid_input_msg flake_inputs selected_inputs selected
		exit 1
	fi
	inputs=("${selected_inputs[@]}")
elif [[ ${#excluded_inputs[@]} -gt 0 ]]; then
	if ! is_in_array flake_inputs excluded_inputs; then
		invalid_input_msg flake_inputs excluded_inputs excluded
		exit 1
	fi
	mapfile -t inputs < <(get_flake_inputs)
	reduce_list inputs excluded_inputs
fi

declare gitmsgfile

gitmsgfile="$(mktemp)"

{
	printf "nix: lock update\n"
	printf "\n"
} >"${gitmsgfile}"

printf "\n"
printf "Updating flake lock file...\n"
printf "\n"

printf "flake inputs: %s\n" "${flake_inputs[*]}"
printf "\n"

if [[ ${#inputs[@]} -gt 0 ]]; then
	printf "Updating inputs: %s\n" "${inputs[*]}"
	printf "\n"
fi | tee -a "${gitmsgfile}"

nix flake update "${inputs[@]}" |& grep -v -E "^warning:" | tee -a "${gitmsgfile}" || true # keep grep from failing script when updates aren't found
printf "\n"

# success -> flake.lock not updated
# failure -> flake.lock updated
if git diff-files --quiet ./flake.lock; then
	printf "INFO: No updates for ./flake.lock found.\n"
else
	git commit --file "${gitmsgfile}" ./flake.lock
	printf "INFO: ./flake.lock updated.\n"
fi
printf "\n"
