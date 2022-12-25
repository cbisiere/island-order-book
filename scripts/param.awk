# ----------------------------------------------------------------------------
#
#  Project : ITCH data
#  Author  : Christophe Bisière
#  Module  : analyze command line parameters
#
# ----------------------------------------------------------------------------
#
#  command-line variables and corresponding global variables:
#    par_output_dir   P_OUTPUT_DIR
#    par_tickers      P_TICKERS (array)
#    par_actions      P_ACTIONS (array)
#    par_book_levels  P_BOOK_LEVELS
#    par_snapshot     P_SNAPSHOT
#    par_limit        P_MAX_TOTAL_RECORDS
#    par_file_limit   P_MAX_RECORDS
#    par_max_display  P_MAX_DISPLAY
#    par_zip          P_COMPRESS
#    par_verbose      P_VERBOSE
#
# ----------------------------------------------------------------------------


# Analyze parameters passed to the awk script, setting corresponding variables.
function set_script_parameters(\
  dir, ar, i, ticker, action)
{

  # output directory
  dir = trim(par_output_dir)
  if (dir == "") {
    dir = "."
  }
  user_check(is_directory(dir), 
      "output directory \"" dir "\" does not exist")
  P_OUTPUT_DIR = dir

  # tickers to consider (or "*" for all tickers)
  if (trim(par_tickers) != "*") {
    split(par_tickers, ar, ",")
    for (i in ar) {
      ticker = trim(ar[i])
      user_check(is_valid_ticker(ticker), "invalid ticker: " ticker)
      P_TICKERS[ticker] = 1
    }
  } else {
    P_TICKERS["*"] = 1
  }

  # requested output data: tickers, best...
  split(par_actions, ar, ",")
  for (i in ar) {
    action = trim(ar[i])
    user_check(action ~ /^(trace|tickers|book|events|best|trades|broken)$/,
        "invalid action: " action)
    P_ACTIONS[ar[i]] = 1
  }

  # number of price levels per side to output in book data files
  user_check(is_positive_integer(par_book_levels),
      "number of price levels per book side must be a positive integer")
  P_BOOK_LEVELS = par_book_levels + 0

  # time interval duration in seconds for snapshots
  user_check(is_positive_integer(par_snapshot),
      "duration of snapshot intervals must be a positive integer")
  P_SNAPSHOT = par_snapshot + 0

  # maximum number of events
  user_check(is_positive_integer(par_limit),
      "overall record limit must be a positive integer")
  P_MAX_TOTAL_RECORDS = par_limit + 0

  # maximum number of events per input file
  user_check(is_positive_integer(par_file_limit),
      "record limit per file must be a positive integer")
  P_MAX_RECORDS = par_file_limit + 0

  # maximum number of orders to display
  user_check(is_positive_integer(par_max_display),
      "order display limit must be a positive integer")
  P_MAX_DISPLAY = par_max_display + 0

  # compress?
  user_check(par_zip == 0 || par_zip == 1,
      "zip option must be 0 or 1")
  P_COMPRESS = par_zip + 0

  # verbose?
  user_check(par_verbose == 0 || par_verbose == 1,
      "verbose option must be 0 or 1")
  P_VERBOSE = par_verbose + 0

  # we should not use the script parameters anymore
  par_output_dir = ""
  par_tickers = ""
  par_actions = ""
  par_book_levels = ""
  par_snapshot = ""
  par_limit = ""
  par_file_limit = ""
  par_max_display = ""
  par_zip = ""
  par_verbose = ""
}
