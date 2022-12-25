# ----------------------------------------------------------------------------
#
#  Project : ITCH data
#  Author  : Christophe Bisière
#  Module  : main
#
# ----------------------------------------------------------------------------
#
#  Usage : see itch.sh
#
#  Example (using mawk):
#
#  mawk -f scripts/mawk.awk -f scripts/tools.awk -f scripts/error.awk
#   -f scripts/itch.awk -f scripts/print.awk -f scripts/market.awk
#   -f scripts/param.awk -f scripts/main.awk 
#   -v par_output_dir=out -v par_tickers=AAPL,MSFT 
#   -v par_actions=trace,tickers,book,events,best,trades,broken 
#   -v par_book_levels=5 -v par_snapshot=300 -v par_max_display=20 
#   -v par_limit=0 -v par_file_limit=0 -v par_zip=0 - v par_verbose=1
#   -- sample/S030800-v1.txt
#
# ----------------------------------------------------------------------------

BEGIN {
  # Track whether an input file is currently processed, and retain awk's
  # field values after awk closes an input file.
  g_file_context = 0
  g_filename = ""
  g_frn = 0

  # NULL constants, for internal and data file output purposes
  g_NULL_r = 0  # order reference
  g_NULL_s = ""  # string
  g_NULL_d = ""  # numerical value
  
  # output file groups
  g_DAT = "DAT" # structured data file
  g_TRA = "TRA" # trace file
  g_STD = "STD" # standard device

  # an attempt to convince the linter not to emit the warning:
  # "accessing fields from an END rule may not be portable"
  g_SUBSEP = SUBSEP

  # current market day, extracted from the current data file name
  m_current_day = ""

  # number of records processed so far
  m_nb_rec = 0
  m_nb_rec_in_current_file = 0

  # did one of those limit has been reached in the current file?
  m_limit_reached = 0

  # version of the current ITCH file: 1 or 2
  m_itch_version = 0

  # current ticker and timestamp
  m_current_ticker = ""
  m_current_timestamp = 0

  # previous order id
  m_pr = g_NULL_r

  # target tickers seen so far (as index, e.g. m_TICKER['MSFT] == 1)
  delete m_TICKER

  # current record read
  delete m_R

  # number of output data record per stock and action
  #  e.g. m_NB_OUT["MSFT", "best"]
  delete m_NB_OUT

  set_script_parameters()
}

END {
  if (!did_exit()) {
    # we are done with the last ITCH file
    end_of_file_tasks()
  }

  close_files_in_group(g_STD)
}

{
  g_frn = FNR

  # we are done with an ITCH file
  if (FNR==1 && NR != FNR) {
    end_of_file_tasks()
  }

  # we process a new ITCH file
  if (FNR == 1) {
    g_file_context = 1
    g_filename = FILENAME

    set_log_filename(g_filename ".log")

    reset_errors()

    m_pr = g_NULL_r

    m_nb_rec_in_current_file = 0

    m_current_day = get_day_from_itch_filename(g_filename)
    if (m_current_day == "") {
      nextfile
    }

    m_limit_reached = 0

    delete m_NB_OUT
    reset_output_file_list()

    m_itch_version = probe_itch_version()
    if (m_itch_version == 0) {
      nextfile
    }
    printk_if(P_VERBOSE, "ITCH data version " m_itch_version " detected")

    reset_market_state()
    set_price_precision(get_itch_price_precision(m_current_day, m_itch_version))
  }

  if (P_MAX_TOTAL_RECORDS && m_nb_rec >= P_MAX_TOTAL_RECORDS) {
    m_limit_reached = 1
    printk_if(P_VERBOSE, m_nb_rec " records: limit reached")
    exit
  }

  if (P_MAX_RECORDS && m_nb_rec_in_current_file >= P_MAX_RECORDS) {
    m_limit_reached = 1
    printk_if(P_VERBOSE, 
      m_nb_rec_in_current_file " records in current file: limit reached")
    nextfile
  }

  # when an error occurred, processing records does not make sense
  if (market_check_has_failed()) {
    nextfile
  }

  # drop carriage returns if any
  sub(/\r/, "")

  # skip empty lines
  if ($0 == "") {
    next
  }

  delete m_R
  get_itch_record(m_R, m_current_day, m_itch_version)
  if (market_check_has_failed()) {
    nextfile
  }

  if (is_itch_system_record(m_R)) {
    process_itch_system_record(m_R)
    next
  }

  # check the market is open
  session_event()

  # solve reference to ticker in record data, such that m_R["ticker"] will
  #  always be set after this instruction
  add_ticker_to_itch_record(m_R)

  # at this point timestamp and ticker are known
  m_current_ticker = m_R["ticker"]
  m_current_timestamp = m_R["timestamp"]

  # tickers not on our target list are not processed
  if (!stock_to_keep(m_current_ticker)) {
    next
  }

  # target tickers for which a check has failed are not processed
  if (ticker_check_has_failed(m_current_ticker)) {
    next
  }

  m_nb_rec += 1
  m_nb_rec_in_current_file += 1

  # note this target tickers has at least a record in the data file
  m_TICKER[m_current_ticker] = 1

  # do snapshots when appropriate
  if ((P_SNAPSHOT > 0) && _must_snapshot(m_current_ticker, m_current_timestamp)) {
    execute_snapshot_actions(m_current_ticker)
  }

  process_itch_ticker_record(m_R)
 
  execute_per_event_actions(m_R)

  if (m_nb_rec % 10000 == 0) {
    printk_if(P_VERBOSE, 
      "Record " FNR ": " m_nb_rec " records processed so far")
  }

}


# Execute what should be done when we are done with a file.
function end_of_file_tasks(\
  ticker, filename)
{
  if (!market_check_has_failed()) {

    # tasks to complete if all the input lines have actually been read
    if (!m_limit_reached) {
      # emit a warning if the end-of-day marker has not been seen
      session_must_be_complete()
    }

    # output end-of-the-day snapshots for all tickers 
    if ((P_SNAPSHOT > 0) && session_is_complete()) {
      execute_pending_snapshot_actions()
    }
  }

  # output tickers
  if ("tickers" in P_ACTIONS) {
    for (ticker in m_TICKER) {
      print_to_file_in_group(g_DAT, ticker, _tickers_filename(m_current_day))
    }
  }

  # close all files 
  close_files_in_group(g_DAT)
  close_files_in_group(g_TRA)
  close_log()

  # compress data files 
  if (P_COMPRESS) {
    compress_files_in_group(g_DAT)
    compress_files_in_group(g_TRA)
  }

  # we are done with the current input file
  g_file_context = 0
}


function stock_to_keep(ticker)
{
  if ("*" in P_TICKERS) {
    return 1
  }
  return (ticker in P_TICKERS)
}


function is_itch_system_record(R)
{
  return R["type"] == "S"
}

# process a system message
function process_itch_system_record(R)
{
  if (R["system"] == "S") {
    printk_if(P_VERBOSE, "Start of Day " R["day"])
    session_start()
  } else if (R["system"] == "E") {
    printk_if(P_VERBOSE, "End of Day " R["day"])
    session_end()
  }
}

# Complete a itch record by solving order or match references, in order
# to get the ticker name when it is not given in the input record itself.
# This function slightly changes the global state, but not the order book 
# itself.
function add_ticker_to_itch_record(R,
  type)
{
  type = R["type"]

  # new visible orders or first hit of hidden orders?
  R["is_new_ref"] = (type == "A") || (type == "P") \
    && !reference_is_known(R["order"])

  # add a new order reference
  if (R["is_new_ref"]) {
    new_reference(R["order"], R["ticker"])
  }

  # add a new match number
  if (index("P", type)) {
    new_match(R["match"], R["ticker"])
  }

  # add ticker to record when not specified
  if (index("EX", type)) {
    R["ticker"] = reference_to_ticker(R["order"])
  }
  if (type == "EB") {
    R["ticker"] = match_to_ticker(R["match"])
  }

  # check the ticker of a hidden order hit is coherent with previous order data
  if ((type == "P") && (!R["is_new_ref"])) {
    ticker_check(R["ticker"], R["ticker"] == reference_to_ticker(R["order"]),
        "hidden order ticker changed" )
  }
}


# process the event in R, adding extra information
function process_itch_ticker_record(R,
  type)
{
  type = R["type"]

  if (!has_book(R["ticker"])) {
    new_book(R["ticker"], R["day"])
  }

  update_book_clock(R["ticker"], R["timestamp"])

  # declare new visible orders and first hit of hidden orders
  if (R["is_new_ref"]) {
    new_order_from_record(R)
  }

  # check hidden order hit is coherent with previous order data
  if ((type == "P") && (!R["is_new_ref"])) {
    ticker_check(R["ticker"], R["bs"] == order_bs(R["order"]),
        "hidden order side changed")
    ticker_check(R["ticker"], R["price"] == order_price(R["order"]),
        "hidden order trade price changed")
    ticker_check(R["ticker"], R["display"] == order_display(R["order"]),
        "hidden order display indicator changed")
  }

  # complete records whenever possible
  if (index("EX", type)) {
    R["bs"] = order_bs(R["order"])
    R["price"] = order_price(R["order"])
    R["display"] = order_display(R["order"])
    R["visibility"] = order_visibility(R["order"])
  }

  # new order references are expected to increase within each day
  if (type == "A") {
    ticker_check(R["ticker"], m_pr == g_NULL_r || R["order"] > m_pr,
        "non increasing order reference ")
    m_pr = R["order"]
  }

  # visible order with the highest priority are hit first
  if (type == "E") {
    ticker_check(R["ticker"], order_is_book_head(R["order"]),
        "price-time priority violation amongst visible orders")
  }

  # event "location" with respect to the current spread
  # Note: must be called after the order is created and, if it is a new limit
  #  order, before it is inserted
  if (index("APEX", type)) {
    R["where"] = order_location(R["order"])
  }

  # marketable limit orders are not supposed to exist
  if (type == "A") {
    ticker_check(R["ticker"], R["where"] != "marketable",
        "marketable limit order")
  }

  # trades against hidden orders are supposed to only occur within the spread
  if (type == "P") {
    ticker_check(R["ticker"], R["where"] == "within",
        "trade with hidden order not inside the spread ")
  }

  # save context information (state before the event)
  R["best_bid"] = best_price(R["ticker"], "B")
  R["best_ask"] = best_price(R["ticker"], "S")
  R["best_bid_q"] = best_quantity(R["ticker"], "B")
  R["best_ask_q"] = best_quantity(R["ticker"], "S")

  #
  # update the state of the order book
  #

  # latent order (undocumented): do nothing
  # see https://www.neovest.com/sales/NeovestTrainingOE.pdf section 5-17
  if (type == "A") {
    ticker_check(R["ticker"], R["display"] != "L",
        "latent order detected.")
  }

  # book update: insert a new limit order into the book
  if (type == "A") {
    insert_order_in_book(R["order"])
  }

  # characteristics of the execution of a visible order hit in the book
  if (type == "E") {
    R["is_marginal"] = order_is_marginal(R["order"])
    R["is_fully_executed"] = (R["shares"] == order_remaining_size(R["order"]))
  }

  # book update: execution or cancellation
  if (index("EX", type)) {
    decrease_order_size(R["order"], R["shares"])
  }

  # event class
  if (type == "A") {
    R["event"] = "ORDER"
  } else if (type == "P" || type == "E") {
    R["event"] = "TRADE"
  } else if (type == "X") {
    R["event"] = "CANCEL"
  } else if (type == "B") {
    R["event"] = "BROKEN"
  }

  # trade sign
  if (R["event"] == "TRADE") {
    R["sign"] = (R["bs"] == "B" ? "S" : "B")
  }
}

#-----------------------------------------------------------------------------
#  user actions
#-----------------------------------------------------------------------------

# execute per event user actions
function execute_per_event_actions(R,
  ticker, type)
{
  ticker =  R["ticker"]
  type = R["type"]

  if ("trace" in P_ACTIONS) {
    _write_to_trace(R)
  }

  if (("events" in P_ACTIONS) && index("APEX", type)) {
    _write_event_record(R)
  }

  if (("trades" in P_ACTIONS) && index("PE", type)) {
    _write_trade_record(R)
  }

  if (("broken" in P_ACTIONS) && (type == "B")) {
    _write_broken_record(R)
  }

  if ((P_SNAPSHOT == 0) && ("best" in P_ACTIONS)) {
    if (R["best_bid"] != best_price(ticker, "B") ||
        R["best_ask"] != best_price(ticker, "S") ||
        R["best_bid_q"] != best_quantity(ticker, "B") ||
        R["best_ask_q"] != best_quantity(ticker, "S")) {
      _write_best_record(R)
    }
  }

  if ((P_SNAPSHOT == 0) && ("book" in P_ACTIONS)) {
    _write_book_record(R)
  }

  # finally, store the processed record for later use (end-of-the-day snapshots)
  set_last_record(ticker, R)
}


# Execute snapshot actions.
function execute_snapshot_actions(ticker,
  R) 
{
  get_last_record(ticker, R)

  if ("best" in P_ACTIONS) {
    _write_best_record(R)
  }

  if ("book" in P_ACTIONS) {
    _write_book_record(R)
  }
}

# Execute pending snapshots for all tickers 
function execute_pending_snapshot_actions(\
  ticker)
{
  for (ticker in m_TICKER) {
    execute_snapshot_actions(ticker)
  } 
}


# Return true if a snapshot of the book state before record R must be done.
function  _must_snapshot(ticker, timestamp, 
  duration_ms, book_interval, new_interval)
{
  # there is nothing to snapshot if the ticker has no book yet
  if (!has_book(ticker)) {
    return 0
  }

  duration_ms = P_SNAPSHOT*1000
  book_interval = int(book_timestamp(ticker)/duration_ms)
  new_interval = int(timestamp/duration_ms)

  # still the same time interval
  if (new_interval == book_interval) {
    return 0
  }

  return 1
}


#-----------------------------------------------------------------------------
#  trace and data output, taking care of accounting, data headers...
#  
#  Note: all the following functions, it is assumed that the book has 
#  already been updated with the event in R
#-----------------------------------------------------------------------------

# Append trace lines to a trace file.
function _write_to_trace(R,
  ticker, day, timestamp, str, fn) 
{
  ticker =  R["ticker"]
  day = R["day"]
  timestamp = R["timestamp"]

  _ticker_nb_out_init(ticker, "trace")

  fn = _trace_filename(ticker, day)
  str = \
      "*** Record " FNR ": " day " " timestamp_for_display(timestamp) "\n\n" \
      get_event_trace(R) "\n" \
      get_trace_book(R) "\n"
  print_to_file_in_group(g_TRA, str, fn)
  m_NB_OUT[ticker, "trace"] += 1
}

# Write a new record in a event data file.
function _write_event_record(R,
  ticker, day, fn) 
{
  ticker =  R["ticker"]
  day = R["day"]

  _ticker_nb_out_init(ticker, "events")

  fn = _output_filename(ticker, day, "EVENTS")
  if (!m_NB_OUT[ticker, "events"]) {
    print_to_file_in_group(g_DAT, get_event_row(R, 1), fn)
  }
  print_to_file_in_group(g_DAT, get_event_row(R, 0), fn)
  m_NB_OUT[ticker, "events"] += 1
}

# Write a new record in a trade data file.
function _write_trade_record(R,
  ticker, day, fn) 
{
  ticker =  R["ticker"]
  day = R["day"]

  _ticker_nb_out_init(ticker, "trades")

  fn = _output_filename(ticker, day, "TRADES")
  if (!m_NB_OUT[ticker, "trades"]) {
    print_to_file_in_group(g_DAT, get_event_row(R, 1), fn)
  }
  print_to_file_in_group(g_DAT, get_event_row(R, 0), fn)
  m_NB_OUT[ticker, "trades"] += 1
}

# Write a new record in a broken data file.
function _write_broken_record(R,
  ticker, day, fn) 
{
  ticker =  R["ticker"]
  day = R["day"]

  _ticker_nb_out_init(ticker, "broken")

  fn = _output_filename(ticker, day, "BROKEN")
  if (!m_NB_OUT[ticker, "broken"]) {
    print_to_file_in_group(g_DAT, get_broken_trade_row(R, 1), fn)
  }
  print_to_file_in_group(g_DAT, get_broken_trade_row(R, 0), fn)
  m_NB_OUT[ticker, "broken"] += 1
}

# Write a new record in a best quotes data file.
function _write_best_record(R,
  ticker, day, fn) 
{
  ticker =  R["ticker"]
  day = R["day"]

  _ticker_nb_out_init(ticker, "best")

  fn = _output_filename(ticker, day, "BEST")
  if (!m_NB_OUT[ticker, "best"]) {
    print_to_file_in_group(g_DAT, get_best_quote_row(R, 1), fn)
  }
  print_to_file_in_group(g_DAT, get_best_quote_row(R, 0), fn)
  m_NB_OUT[ticker, "best"] += 1
}

# Write a new record in a book data file.
function _write_book_record(R,
  ticker, day, fn) 
{
  ticker =  R["ticker"]
  day = R["day"]

  _ticker_nb_out_init(ticker, "book")

  fn = _output_filename(ticker, day, "BOOK")
  if (!m_NB_OUT[ticker, "book"]) {
    print_to_file_in_group(g_DAT, get_book_row(R, 1), fn)
  }
  print_to_file_in_group(g_DAT, get_book_row(R, 0), fn)
  m_NB_OUT[ticker, "book"] += 1
}

# Initialize the number of output line for a given output type.
# This keeps lint quiet.
function _ticker_nb_out_init(ticker, type)
{
  if (!((ticker g_SUBSEP type) in m_NB_OUT)) {
    m_NB_OUT[ticker, type] = 0
  }
}

#-----------------------------------------------------------------------------
#  output filenames
#-----------------------------------------------------------------------------

function _output_filename(ticker, day, tag,
  filename)
{
  filename = P_OUTPUT_DIR "/" ticker "-" day "-" tag ".txt"
  return filename
}

function _trace_filename(ticker, day)
{
  return _output_filename(ticker, day, "TRACE")
}

function _tickers_filename(day)
{
  return _output_filename("", day, "TICKERS")
}

