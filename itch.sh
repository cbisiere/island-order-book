#!/usr/bin/env bash
#
# Script to extract data from ITCH files
#
# Author: Christophe Bisière
# This project is licensed under the MIT License

readonly SCRIPT_NAME="${0##*/}"
readonly USAGE="${SCRIPT_NAME} [-h] [-o directory] [-t tickers]\
 [-a actions] [-b book-levels] [-s snapshot] [-m max-display] [-l limit]\
 [-l file-limit] [-p preferred-awk] [-z] [-v] [-d] file [file...]

where:
    -h, --help           show this help text
    -o, --output-dir     directory where extracted data will be stored
                         (defaults to '.')
    -t, --tickers        comma-separated list of stock tickers to work on
                         (e.g. 'AAPL,MSFT', defaults to '*')
    -a, --actions        comma-separated list of data to compute:
                         trace, tickers, book, events, best, trades, broken
                         (e.g. 'trace,tickers,best')
    -b, --book-levels    number of price level to save on both sides of
                         the book, for action 'book'
                         (e.g. 10, default to 5)  
    -s, --snapshot       duration of the snapshot time intervals, in seconds,
                         for action 'book' and action 'best'
                         (e.g. 300 for 5 minutes, defaults to 0: output all)
    -m, --max-display    maximum number of orders to display per book side
                         in the book trace
                         (e.g. 15, defaults to 10, 0 means no limit)
    -l, --limit          maximum overall number of events to process
                         (e.g. 1000, defaults to 0: no limit)
    -f, --file-limit     maximum number of events to process per input file
                         (e.g. 100, defaults to 0: no limit)
    -p, --preferred-awk  preferred awk version to use
                         ('awk', 'gawk', 'mawk' or 'nawk', defaults to 'awk')
    -z, --zip            gzip each output file
    -v, --verbose        print feedback about what the script is doing
    -d, --debug          print debug information"

# options with default values
# these variables will be set as readonly later on

OPT_OUTPUT_DIR='.'    # output directory
OPT_TARGET_TICKERS='*'
OPT_ACTIONS=''
OPT_BOOK_LEVELS='5'
OPT_SNAPSHOT='0'
OPT_MAX_DISPLAY='10'
OPT_LIMIT='0'
OPT_FILE_LIMIT='0'
OPT_AWK='awk'
OPT_COMPRESS=0        # compress each output file
OPT_VERBOSE=0         # print feedbacks
OPT_DEBUG=0           # print debug info
ARG_FILES=""          # other atguments

# print usage
usage(){
  echo "Usage: ${USAGE}" 1>&2
}

# die with an error message
die(){
  local message="$1"

  echo "Error: ${message}. Aborting." 1>&2
  exit 1
}

# check a command is available and die if it is not
program_exists(){
  command -v "$1" > /dev/null 2>&1
}

# check a command is available and die if it is not
check_program(){
  local command="$1"

  if ! program_exists "${command}"; then
    die "${command} not installed. Please install ${command}"
  fi
}

# check getopt is available and is GNU getopt
check_getopt(){
  check_program getopt

  # gnu "getopt -T" returns an exit code 4 and no output
  local output
  output=$(getopt -T)
  if (( $? != 4 )) && [[ -n $output ]]; then
    die "non-gnu getopt"
  fi
}


# get and check options
# side effect: this function sets opt_* global variables
get_and_check_options(){

  local options
  local lo
  local so

  lo="output-dir:,tickers:,actions:,book-levels:,max-display:,\
    limit:,file-limit:,snapshot:,preferred-awk:,help,zip,verbose,debug"
  so="o:t:a:b:m:l:f:s:p:hzvd"

  options=$(getopt --name "${SCRIPT_NAME}" \
    --longoptions  "$lo"\
    --options  "$so" -- "$@")

  [[ $? -eq 0 ]] || {
    usage
    die "invalid option"
  }

  eval set -- "${options}"


  # extract options and their arguments
  while true; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -o|--output-dir)
        OPT_OUTPUT_DIR=$2
        shift 2
        ;;
      -t|--tickers)
        OPT_TARGET_TICKERS=$2
        shift 2
        ;;
      -a|--actions)
        OPT_ACTIONS=$2
        shift 2
        ;;
      -b|--book-levels)
        OPT_BOOK_LEVELS=$2
        shift 2
        ;;
      -f|--snapshot)
        OPT_SNAPSHOT=$2
        shift 2
        ;;
      -m|--max-display)
        OPT_MAX_DISPLAY=$2
        shift 2
        ;;
      -l|--limit)
        OPT_LIMIT=$2
        shift 2
        ;;
      -f|--file-limit)
        OPT_FILE_LIMIT=$2
        shift 2
        ;;
      -p|--preferred-awk)
        OPT_AWK=$2
        shift 2
        ;;
      -z|--zip)
        OPT_COMPRESS=1
        shift
        ;;
      -v|--verbose)
        OPT_VERBOSE=1
        shift
        ;;
      -d|--debug)
        OPT_DEBUG=1
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        die "unknown option: $1" ;;
    esac
    # what remains in $@ is the itch files to process
    ARG_FILES="$@"
  done

  # gzip is required if compression is requested
  [[ "${OPT_COMPRESS}" == 1 ]] && {
    check_program gzip
  }

  # check awk
  local awk_re='^(awk|gawk|mawk|nawk)$'
  [[ "${OPT_AWK}" =~ ${awk_re} ]] || {
    die "option --preferred-awk: preferred awk version must be awk, gawk, mawk or nawk: '${OPT_AWK}'"
  }
  check_program "${OPT_AWK}"

  # check arguments
  local int_re="^([1-9][0-9]*|0)$"
  [[ "${OPT_BOOK_LEVELS}" =~ ${int_re} ]] || {
    die "option --book-levels: number of price levels per book side must be a positive integer: '${OPT_BOOK_LEVELS}'"
  }
  [[ "${OPT_LIMIT}" =~ ${int_re} ]] || {
    die "option --limit: event limit must be a positive integer: '${OPT_LIMIT}'"
  }
  [[ "${OPT_SNAPSHOT}" =~ ${int_re} ]] || {
    die "option --snapshot: duration of snapshot intervals must be a positive integer: '${OPT_FILE_LIMIT}'"
  }
  [[ "${OPT_FILE_LIMIT}" =~ ${int_re} ]] || {
    die "option --file-limit: event limit per file must be a positive integer: '${OPT_FILE_LIMIT}'"
  }
  [[ "${OPT_MAX_DISPLAY}" =~ ${int_re} ]] || {
    die "option --max-display: display limit per book side must be a positive integer: '${OPT_MAX_DISPLAY}'"
  }

  [[ -d "${OPT_OUTPUT_DIR}" ]] || {
    die "option --output-dir: output directory '${OPT_OUTPUT_DIR}' does not exist"
  }

  local ticker_re='[A-Z]{4,6}'
  local tickers_re="^${ticker_re}(,${ticker_re})*$"
  [[ "${OPT_TARGET_TICKERS}" == "*" || "${OPT_TARGET_TICKERS}" =~ ${tickers_re} ]] || {
    die "option --tickers: invalid ticker in '${OPT_TARGET_TICKERS}'"
  }

  local action_re='(trace|tickers|book|events|best|trades|broken)'
  local actions_re="^${action_re}(,${action_re})*$"
  [[ "${OPT_ACTIONS}" == "" || "${OPT_ACTIONS}" =~ ${actions_re} ]] || {
    die "option --actions: unknown action '${OPT_ACTIONS}'"
  }

}


main(){
  # some programs are always required
  check_getopt

  # set opt_* global variables
  get_and_check_options "$@"

  readonly OPT_OUTPUT_DIR
  readonly OPT_TARGET_TICKERS
  readonly OPT_ACTIONS
  readonly OPT_BOOK_LEVELS
  readonly OPT_SNAPSHOT
  readonly OPT_MAX_DISPLAY
  readonly OPT_LIMIT
  readonly OPT_FILE_LIMIT
  readonly OPT_AWK
  readonly OPT_COMPRESS
  readonly OPT_VERBOSE
  readonly OPT_DEBUG
  readonly ARG_FILES

  [[ "${OPT_DEBUG}" == 1 ]] && {
    echo "Parameters:"
    echo "  --output-dir      : ${OPT_OUTPUT_DIR}"
    echo "  --tickers         : ${OPT_TARGET_TICKERS}"
    echo "  --actions         : ${OPT_ACTIONS}"
    echo "  --book-levels     : ${OPT_BOOK_LEVELS}"
    echo "  --snapshot        : ${OPT_SNAPSHOT}"
    echo "  --max-display     : ${OPT_MAX_DISPLAY}"
    echo "  --limit           : ${OPT_LIMIT}"
    echo "  --file-limit      : ${OPT_FILE_LIMIT}"
    echo "  --awk             : ${OPT_AWK}"
    echo "  --zip             : ${OPT_COMPRESS}"
    echo "  --verbose         : ${OPT_VERBOSE}"
    echo "  --debug           : ${OPT_DEBUG}"
  }

  local PARA
  local SCRIPTS
  local CMD

  PARA=""
  [[ "$OPT_AWK" == "gawk" && "${OPT_DEBUG}" == 1 ]] && {
      PARA+=" --lint=no-ext --dump-variables"
  }
  [[ ! -z "$OPT_OUTPUT_DIR" ]] && {
      PARA+=" -v par_output_dir=${OPT_OUTPUT_DIR}"
  }
  [[ ! -z "$OPT_TARGET_TICKERS" ]] && {
      PARA+=" -v par_tickers=${OPT_TARGET_TICKERS}"
  }
  [[ ! -z "$OPT_ACTIONS" ]] && {
      PARA+=" -v par_actions=${OPT_ACTIONS}"
  }
  [[ ! -z "$OPT_BOOK_LEVELS" ]] && {
      PARA+=" -v par_book_levels=${OPT_BOOK_LEVELS}"
  }
  [[ ! -z "$OPT_SNAPSHOT" ]] && {
      PARA+=" -v par_snapshot=${OPT_SNAPSHOT}"
  }
  [[ ! -z "$OPT_MAX_DISPLAY" ]] && {
      PARA+=" -v par_max_display=${OPT_MAX_DISPLAY}"
  }
  [[ ! -z "$OPT_LIMIT" ]] && {
      PARA+=" -v par_limit=${OPT_LIMIT}"
  }
  [[ ! -z "$OPT_FILE_LIMIT" ]] && {
      PARA+=" -v par_file_limit=${OPT_FILE_LIMIT}"
  }
  [[ ! -z "$OPT_COMPRESS" ]] && {
      PARA+=" -v par_zip=${OPT_COMPRESS}"
  }
  [[ ! -z "$OPT_VERBOSE" ]] && {
      PARA+=" -v par_verbose=${OPT_VERBOSE}"
  }

  readonly AWK_DIR="scripts"
  SCRIPTS="\
    -f ${AWK_DIR}/${OPT_AWK}.awk \
    -f ${AWK_DIR}/tools.awk \
    -f ${AWK_DIR}/error.awk \
    -f ${AWK_DIR}/itch.awk \
    -f ${AWK_DIR}/print.awk \
    -f ${AWK_DIR}/market.awk \
    -f ${AWK_DIR}/param.awk \
    -f ${AWK_DIR}/main.awk"
  CMD="${OPT_AWK} ${SCRIPTS} ${PARA} ${ARG_FILES}"
  [[ "${OPT_DEBUG}" == 1 ]] && {
      echo "Command: ${CMD}" | tr -s ' '
  }
  $CMD
  exit 0
}

main "$@"
exit 0
