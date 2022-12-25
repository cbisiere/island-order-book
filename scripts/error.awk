# ----------------------------------------------------------------------------
#
#  Project : ITCH data
#  Author  : Christophe Bisière
#  Module  : error handling
#
# ----------------------------------------------------------------------------

BEGIN {

  # number of errors per ticker (e.g. m_ERR["MSFT"])
  delete m_ERR

  # ticker that denotes an event related to the market as a whole, or to
  #  an unknown ticker
  m_MARKET_TICKER = "market"
}


#-----------------------------------------------------------------------------
# public functions: errors on user provided data (parameters)
#-----------------------------------------------------------------------------

# Check related to a user provided value, and exit if it fails.
# Note that an exit from the BEGIN rule occurred.
function user_check(cond, msg)
{
  if (!cond) {
    write_to_stderr("Fatal error: " msg)
    do_exit()
  }
}

#-----------------------------------------------------------------------------
# public functions: errors on ITCH data
#-----------------------------------------------------------------------------

function reset_errors()
{
  delete m_ERR
}

# Do a check related to a particular ticker.
# If the test fails, the current record is skipped but we continue processing
#  the file.
function ticker_check(ticker, cond, msg) 
{
  if (ticker_check_has_failed(ticker)) {
    return 0
  }
  return _check(ticker, cond, msg)
}

function ticker_check_has_failed(ticker)
{
  return _ticker_error_count(ticker) > 0
}

# Do a check not related to a specific ticker, that is, when the ticker is
#  not known yet, or when the check is about the market as a whole.
# If the test fails the whole file is considered as corrupted, and skipped.
function file_check(cond, msg) 
{
  if (market_check_has_failed()) {
    return 0
  }
  return _check(m_MARKET_TICKER, cond, msg)
}

function market_check_has_failed()
{
  return ticker_check_has_failed(m_MARKET_TICKER)
}


#-----------------------------------------------------------------------------
# private functions
#-----------------------------------------------------------------------------

# Return 1 if a condition concerning a ticker (or the market as a whole)
#  and 0 otherwise.
function _check(ticker, cond, msg)
{
  if (cond) {
    return 1
  }

  # accounting: number of errors per ticker
  m_ERR[ticker] = _ticker_error_count(ticker) + 1

  printk("Error: " (ticker == m_MARKET_TICKER ? "" : ticker ": ") msg)

  # core dump
  writeln2log(market_state_as_string())

  return 0
}

# Return the number of error that occurred for a given ticket.
function _ticker_error_count(ticker)
{
  if (!(ticker in m_ERR)) {
    return 0
  }
  return m_ERR[ticker]
}
