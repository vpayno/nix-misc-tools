# shellcheck shell=bash

usage() {
	{
		cat <<-EOF
			Usage: ${0}

			  -l | --list-inputs               :   show flake inputs
			  -i | --include <input1,input2>   :   comma separated list of inputs to update
			  -e | --exclude <input3,input4>   :   comma separated list of inputs to exclude from the update
			  -s | --serial-update             :   update inputs one at a time

			  -d | --show-update-diff-only     :   only show lock update diff
			  -n | --dry-run                   :   do everything but updating flake.lock
			  -h | --help                      :   show usage and exit(2)

			Valid flake inputs: ${flake_inputs[*]// /,}
		EOF
	} 1>&2
	exit 2
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

declare -a flake_inputs=()
declare -a selected_inputs=()
declare -a excluded_inputs=()

mapfile -t flake_inputs < <(get_flake_inputs)

declare parsed_args
declare -i invalid_args=0

declare options_short="hndlsi:e:"
declare options_long="help,dry-run,show-update-diff-only,list-inputs,serial-update,include:,exclude:"

parsed_args="$(getopt --name "$(basename "${0}")" --options "${options_short}" --longoptions "${options_long}" -- "${@}")" || invalid_args="${?}"

if [[ ${invalid_args} -ne 0 ]]; then
	printf "\n"
	usage
fi

eval set -- "${parsed_args}"

declare MODE_CHANGELOG_ONLY=false
declare MODE_DRY_RUN=false
declare MODE_SERIAL_RUN=false

while :; do
	case "${1}" in
	-l | --list-inputs)
		get_flake_inputs
		exit
		;;
	-d | --show-update-diff-only)
		MODE_CHANGELOG_ONLY=true
		printf "INFO: %s selected\n" "--show-update-diff-only"
		shift 1
		;;
	-i | --include)
		mapfile -t selected_inputs < <(sed -r -e 's/,/\n/g' <<<"${2}")
		shift 2
		;;
	-e | --exclude)
		mapfile -t excluded_inputs < <(sed -r -e 's/,/\n/g' <<<"${2}")
		shift 2
		;;
	--)
		shift
		break
		;;
	-n | --dry-run)
		MODE_DRY_RUN=true
		printf "INFO: %s selected\n" "--dry-run"
		shift
		;;
	-s | --serial-update)
		MODE_SERIAL_RUN=true
		printf "INFO: %s selected\n" "--serial-update"
		shift
		;;
	-h | --help)
		usage
		;;
	esac
done
printf "\n"
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
} | tee "${gitmsgfile}"

printf "\n"
printf "Updating flake lock file...\n"
printf "\n"

{
	printf "flake inputs: %s\n" "${flake_inputs[*]}"
	printf "\n"
} | tee -a "${gitmsgfile}"

if [[ ${#excluded_inputs[@]} -gt 0 ]]; then
	printf "Excluded inputs: %s\n" "${excluded_inputs[*]}"
	printf "\n"
fi | tee -a "${gitmsgfile}"

if "${MODE_SERIAL_RUN}"; then
	# serial run - really means running update for each input
	if [[ ${#selected_inputs[@]} -eq 0 && ${#inputs[@]} -eq 0 ]]; then
		mapfile -t inputs < <(get_flake_inputs)
	fi

	declare input
	for input in "${inputs[@]}"; do
		# add ingle input name to commit subject
		sed -r -i -e "s/(nix: lock update)/\1 - ${input}/g" "${gitmsgfile}"

		{
			printf "Updating input: %s\n" "${input}"
			printf "\n"
		} | tee -a "${gitmsgfile}"

		if "${MODE_DRY_RUN}"; then
			echo Pretending to Run: nix flake update "${input}"
		else
			echo Running: nix flake update "${input}"
			nix flake update "${input}" |& grep -v -E "^warning:" | tee -a "${gitmsgfile}" || true # keep grep from failing script when updates aren't found
		fi
		printf "\n"

		# success -> flake.lock not updated
		# failure -> flake.lock updated
		if git diff-files --quiet ./flake.lock; then
			printf "INFO: No updates for ./flake.lock found.\n"
		else
			if "${MODE_CHANGELOG_ONLY}"; then
				printf "Showing update diff/changelog only.\n"
				printf "\n"
				git restore ./flake.lock
				exit 1
			else
				git commit --file "${gitmsgfile}" ./flake.lock
				printf "INFO: ./flake.lock updated.\n"
			fi
		fi
		printf "\n"

		# reset commit subject
		sed -r -i -e "s/(nix: lock update) - [- a-zA-Z0-9]*$/\1/g" "${gitmsgfile}"
	done
else
	if [[ ${#inputs[@]} -gt 0 ]]; then
		printf "Updating inputs: %s\n" "${inputs[*]}"
		printf "\n"
	fi | tee -a "${gitmsgfile}"

	# parallel run - really means only running update once
	if "${MODE_DRY_RUN}"; then
		echo Pretending to Run: nix flake update "${inputs[@]}"
	else
		echo Running: nix flake update "${inputs[@]}"
		nix flake update "${inputs[@]}" |& grep -v -E "^warning:" | tee -a "${gitmsgfile}" || true # keep grep from failing script when updates aren't found
	fi
	printf "\n"

	# success -> flake.lock not updated
	# failure -> flake.lock updated
	if git diff-files --quiet ./flake.lock; then
		printf "INFO: No updates for ./flake.lock found.\n"
	else
		if "${MODE_CHANGELOG_ONLY}"; then
			printf "Showing update diff/changelog only.\n"
			printf "\n"
			git restore ./flake.lock
			exit 1
		else
			git commit --file "${gitmsgfile}" ./flake.lock
			printf "INFO: ./flake.lock updated.\n"
		fi
	fi
fi
printf "\n"
