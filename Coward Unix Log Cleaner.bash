#!/usr/bin/env bash
# A log cleaner for some circumstances logs are not needed
# Copyright © 林博仁 <Buo.Ren.Lin@gmail.com> 2021
# This file is licensed under GPL version 3 or its recent versions, refer The GNU General Public License <https://www.gnu.org/licenses/gpl.html> for more information
# 
# We uses unused variables for convenience
# shellcheck disable=SC2034

## Makes debuggers' life easier - Unofficial Bash Strict Mode
## BASHDOC: Shell Builtin Commands - Modifying Shell Behavior - The Set Builtin
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

for required_command in\
	basename\
	date\
	dirname\
	find\
	id\
	less\
	mktemp\
	realpath\
	rm\
	tr\
	truncate\
	xargs
	do
	if ! command -v "${required_command}" &>/dev/null; then
		printf --\
			'Fatal: This program requires %s, but it is not found in the executable search directories\n'\
			"${required_command}"
		exit 1
	fi
done

## Non-overridable Primitive Variables
## BASHDOC: Shell Variables » Bash Variables
## BASHDOC: Basic Shell Features » Shell Parameters » Special Parameters
if [ -v "BASH_SOURCE[0]" ]; then
	RUNTIME_EXECUTABLE_PATH="$(realpath --strip "${BASH_SOURCE[0]}")"
	RUNTIME_EXECUTABLE_FILENAME="$(basename "${RUNTIME_EXECUTABLE_PATH}")"
	RUNTIME_EXECUTABLE_NAME="${RUNTIME_EXECUTABLE_FILENAME%.*}"
	RUNTIME_EXECUTABLE_DIRECTORY="$(dirname "${RUNTIME_EXECUTABLE_PATH}")"
	RUNTIME_COMMANDLINE_BASECOMMAND="${0}"
	declare -r\
		RUNTIME_EXECUTABLE_FILENAME\
		RUNTIME_EXECUTABLE_DIRECTORY\
		RUNTIME_EXECUTABLE_PATHABSOLUTE\
		RUNTIME_COMMANDLINE_BASECOMMAND
else
	RUNTIME_EXECUTABLE_PATH=null
	RUNTIME_EXECUTABLE_FILENAME=__stdin__
	RUNTIME_EXECUTABLE_NAME=__stdin__
	RUNTIME_EXECUTABLE_DIRECTORY=null
	RUNTIME_COMMANDLINE_BASECOMMAND=__stdin__
fi
declare -ar RUNTIME_COMMANDLINE_PARAMETERS=("${@}")

declare launch_time; launch_time="$(date +%c)"
declare temporary_directory_name="${RUNTIME_EXECUTABLE_NAME}.${launch_time}.XXX"
declare temp_directory
declare remove_temp_directory_at_exit="Y"

# Delete OR Truncate files from a file list
# action: remove / truncate
# file_list: path of file list(files separated with null character)
process_file_list(){
	if [ ${#} -ne 2 ]; then
		printf --\
			'Fatal: %s: Function paramater quantity mismatch!  Please report bug\n'\
			"${FUNCNAME[0]}"\
			1>&2
		exit 1
	fi

	local action="${1}"; shift
	local file_list="${1}"

	local remove_command="rm"
	local truncate_command="truncate --size=0"
	local final_command

	case "${action}" in
		remove)
			final_command="${remove_command}"
		;;
		truncate)
			final_command="${truncate_command}"
		;;
		*)
			printf --\
				'Fatal: %s: Impossible case encountered, please report bug.\n'\
				"${FUNCNAME[0]}"\
				1>&2
			exit 1
		;;
	esac

	# Intentionally allow final_command argument to be seperate by space to words
	# shellcheck disable=SC2086
	xargs\
		--null\
		--no-run-if-empty\
		--max-args=1\
		--verbose\
		${final_command}\
		<"${file_list}"
}; declare -rf process_file_list

# Prompt for Yy/Nn, if not the expected answer ask again
# Parameter: A string of prompt; Default answer(Y/N)
# return 0 for yes and 1 for no
prompt_yes_or_no(){
	if [ ${#} -ne 2 ]; then
		printf --\
			'Fatal: %s: Function paramater quantity mismatch!  Please report bug\n'\
			"${FUNCNAME[0]}"\
			1>&2
		exit 1
	fi

	local -r prompt="${1}"; shift
	local -r default_answer="${1}"

	local -i default_answer_exit_status

	# Validate input
	case "${default_answer}" in
		Y|y)
			default_answer_exit_status=0
		;;
		N|n)
			default_answer_exit_status=1
		;;
		*)
			printf --\
				'Fatal: %s: Wrong default_answer parameter format\n'\
				"${FUNCNAME[0]}"\
				1>&2
			exit 1
		;;
	esac

	# Do the job here
	printf --\
		"%s"\
		"${prompt}"
	while read -r answer; do
		case ${#answer} in
			0) # default
				return ${default_answer_exit_status}
			;;
			1)
				case "${answer}" in
					n|N)
						return 1
					;;
					y|Y)
						return 0
					;;
					*)
						printf --\
							"%s"\
							"${prompt}"
					;;
				esac
			;;
			*)
				printf --\
					'Error: %s: Unexpected case occurred, please report bug.\n'\
					"${FUNCNAME[0]}"\
					1>&2
				exit 1
			;;
		esac
	done
}; declare -rf prompt_yes_or_no

## init function: entrypoint of main program
## This function is called near the end of the file,
## with the script's command-line parameters as arguments
init(){
	declare is_superuser="N"
	declare find_common_options="-regextype egrep -type f"

	if ! process_commandline_parameters; then
		printf\
			'Error: %s: Invalid command-line parameters.\n'\
			"${FUNCNAME[0]}"\
			1>&2
		print_help
		exit 1
	fi

	temp_directory="$(
		mktemp\
		--directory\
		--tmpdir\
		"${temporary_directory_name}"
	)"

	if [ "$(id --user)" != 0 ]; then
		printf --\
			'Error: %s: Not run as Superuser, will not attempt actions that requires Superuser permission.\n'\
			"${FUNCNAME[0]}"\
			1>&2
		is_superuser="N"
	else
		is_superuser="Y"
	fi

	# Cleaning user logs
	# Refer README.markdown for targets
	

	# Cleaning system logs
	# Refer README.markdown for targets
	if [ "${is_superuser}" == "Y" ]; then
		# find_common_options is intended to be separated by space to words
		# shellcheck disable=SC2086
		find\
			/var/log\
			${find_common_options}\
			\(\
				-regex '^.*/.+\.[[:digit:]]+(\.[[:alpha:]]+)?$'\
				-o\
				-iregex '^.*/.+\.old$'\
			\)\
			-print0\
			>"${temp_directory}/system_rotated_log_list.print0"
		tr\
			'\0'\
			'\n'\
			<"${temp_directory}/system_rotated_log_list.print0"\
			>"${temp_directory}/system_rotated_log_list"
		printf --\
			'Press enter to start reviewing the list of the files to be deleted in a pager, press "q" to exit the pager.'
		while ! read -r answer; do :; done
		less\
			"${temp_directory}/system_rotated_log_list"
		if prompt_yes_or_no\
			'Are you sure you want to delete these files(y/N)? '\
			N; then
			process_file_list\
				remove\
				"${temp_directory}/system_rotated_log_list.print0"
		fi
		
		find\
			/var/log\
			-regextype egrep\
			-iregex '^.*/.+\.log$'\
			-print0\
			>"${temp_directory}/system_to_be_truncated_log_list.print0"
		tr\
			'\0'\
			'\n'\
			<"${temp_directory}/system_to_be_truncated_log_list.print0"\
			>"${temp_directory}/system_to_be_truncated_log_list"
		printf --\
			'Press enter to start reviewing the list of the files to be truncated in a pager, press "q" to exit the pager.'
		while ! read -r answer; do :; done
		less\
			"${temp_directory}/system_to_be_truncated_log_list"
		if prompt_yes_or_no\
			'Are you sure you want to truncate these files(y/N)? '\
			N; then
			process_file_list\
				truncate\
				"${temp_directory}/system_to_be_truncated_log_list.print0"
		fi
	else
		find\
			~/\
			${find_common_options}\
			\(\
				-regex '^.*/.+\.log\.[[:digit:]]+(\.[[:alpha:]]+)?$'\
				-o\
				-iregex '^.*/.+\.old$'\
			\)\
			-print0\
			>"${temp_directory}/user_rotated_log_list.print0"
		tr\
			'\0'\
			'\n'\
			<"${temp_directory}/user_rotated_log_list.print0"\
			>"${temp_directory}/user_rotated_log_list"
		printf --\
			'Press enter to start reviewing the list of the files to be deleted in a pager, press "q" to exit the pager.'
		while ! read -r answer; do :; done
		less\
			"${temp_directory}/user_rotated_log_list"
		if prompt_yes_or_no\
			'Are you sure you want to delete these files(y/N)? '\
			N; then
			process_file_list\
				remove\
				"${temp_directory}/user_rotated_log_list.print0"
		fi
		# TODO: fix
		find\
			~/\
			-regextype egrep\
			-iregex '^.*/.+\.log$'\
			-print0\
			>"${temp_directory}/user_to_be_truncated_log_list.print0"
		tr\
			'\0'\
			'\n'\
			<"${temp_directory}/user_to_be_truncated_log_list.print0"\
			>"${temp_directory}/user_to_be_truncated_log_list"
		printf --\
			'Press enter to start reviewing the list of the files to be truncated in a pager, press "q" to exit the pager.'
		while ! read -r answer; do :; done
		less\
			"${temp_directory}/user_to_be_truncated_log_list"
		if prompt_yes_or_no\
			'Are you sure you want to truncate these files(y/N)? '\
			N; then
			process_file_list\
				truncate\
				"${temp_directory}/user_to_be_truncated_log_list.print0"
		fi

	fi
}; declare -fr init

## Traps: Functions that are triggered when certain condition occurred
## Shell Builtin Commands » Bourne Shell Builtins » trap
trap_errexit(){
	printf 'An error occurred and the script is prematurely aborted\n' 1>&2

	remove_temp_directory_at_exit="N" 
	return 0
}; declare -fr trap_errexit; trap trap_errexit ERR

trap_exit(){
	if [ "${remove_temp_directory_at_exit}" == "N" ]; then
		printf --\
			'Info: Working directory "%s" is not removed for error investigation.\n'\
			"${temp_directory}"
	else # remove_temp_directory_at_exit = Y
		rm\
			--recursive\
			"${temp_directory}"
	fi

	return 0
}; declare -fr trap_exit; trap trap_exit EXIT

trap_return(){
	local returning_function="${1}"

	printf 'DEBUG: %s: returning from %s\n' "${FUNCNAME[0]}" "${returning_function}" 1>&2
}; declare -fr trap_return

trap_interrupt(){
	printf 'Recieved SIGINT, script is interrupted.\n' 1>&2
	remove_temp_directory_at_exit="N" 
	exit 0
}; declare -fr trap_interrupt; trap trap_interrupt INT

print_help(){
	printf 'Currently no help messages are available for this program\n' 1>&2
	return 0
}; declare -fr print_help;

process_commandline_parameters() {
	if [ "${#RUNTIME_COMMANDLINE_PARAMETERS[@]}" -eq 0 ]; then
		return 0
	fi

	# modifyable parameters for parsing by consuming
	local -a parameters=("${RUNTIME_COMMANDLINE_PARAMETERS[@]}")

	# Normally we won't want debug traces to appear during parameter parsing, so we  add this flag and defer it activation till returning(Y: Do debug)
	local enable_debug=N

	while true; do
		if [ "${#parameters[@]}" -eq 0 ]; then
			break
		else
			case "${parameters[0]}" in
				'--help'\
				|'-h')
					print_help;
					exit 0
					;;
				'--debug'\
				|'-d')
					enable_debug="Y"
					;;
				*)
					printf 'ERROR: Unknown command-line argument "%s"\n' "${parameters[0]}" >&2
					return 1
					;;
			esac
			# shift array by 1 = unset 1st then repack
			unset "parameters[0]"
			if [ "${#parameters[@]}" -ne 0 ]; then
				parameters=("${parameters[@]}")
			fi
		fi
	done

	if [ "${enable_debug}" = "Y" ]; then
		trap 'trap_return "${FUNCNAME[0]}"' RETURN
		set -o xtrace
	fi
	return 0
}; declare -fr process_commandline_parameters;

init "${@}"

## This script is based on the GNU Bash Shell Script Template project
## https://github.com/Lin-Buo-Ren/GNU-Bash-Shell-Script-Template
## and is based on the following version:
declare -r META_BASED_ON_GNU_BASH_SHELL_SCRIPT_TEMPLATE_VERSION="v1.26.0-32-g317af27-dirty"
## You may rebase your script to incorporate new features and fixes from the template
