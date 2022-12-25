# ----------------------------------------------------------------------------
#
#  Project : ITCH data
#  Author  : Christophe Bisière
#  Module  : decode ITCH data
#
# ----------------------------------------------------------------------------
#
#  Important note on ITCH version 2.0:
#
#  Working with ITCH-v2 prices is hopeless. Because v2-to-v1 is not
#  injective, it is not possible to recover unrounded v1 prices from v2
#  prices. In other words, without looking at the v1 prices we would not
#  know whether a v2 price has been rounded or not. As a result, building
#  an order book using v2 prices triggers errors as e.g. execution of
#  hidden orders not strictly within the best quotes.
#
#  https://web.archive.org/web/20020126163429/http://www.island.com/decimals/decimalchart.htm#
#
#  https://web.archive.org/web/20020202161948/http://www.island.com/decimals/faq.htm#How%20will%20decimal%20trading%20on%20Island%20work?
#
# ----------------------------------------------------------------------------

BEGIN {

  CONVFMT = "%.15f"  # increased from 10 to 15 on 2004-06-30 (spurious rounding)

  # type of fields collected or calculated for a given event
  g_FIELD_TYPE["ticker"] = "string"
  g_FIELD_TYPE["day"] = "string"
  g_FIELD_TYPE["timestamp"] = "integer"
  g_FIELD_TYPE["event"] = "string"
  g_FIELD_TYPE["order"] = "integer"
  g_FIELD_TYPE["is_new_ref"] = "integer"
  g_FIELD_TYPE["bs"] = "string"
  g_FIELD_TYPE["shares"] = "integer"
  g_FIELD_TYPE["where"] = "string"
  g_FIELD_TYPE["price"] = "float"
  g_FIELD_TYPE["visibility"] = "string"
  g_FIELD_TYPE["display"] = "string"
  g_FIELD_TYPE["match"] = "integer"
  g_FIELD_TYPE["sign"] = "string"
  g_FIELD_TYPE["is_marginal"] = "integer"
  g_FIELD_TYPE["is_fully_executed"] = "integer"
  g_FIELD_TYPE["best_bid"] = "float"
  g_FIELD_TYPE["best_ask"] = "float"
  g_FIELD_TYPE["best_bid_q"] = "integer"
  g_FIELD_TYPE["best_ask_q"] = "integer"

  # all ITCH record types
  m_RECORD_TYPES = "ASEXPB"

  # record length (ITCH v1)
  m_RECORD_LENGTH["A", 1] = 54
  m_RECORD_LENGTH["S", 1] = 9
  m_RECORD_LENGTH["E", 1] = 39
  m_RECORD_LENGTH["X", 1] = 26
  m_RECORD_LENGTH["P", 1] = 66
  m_RECORD_LENGTH["B", 1] = 17

  # record length (ITCH v2)
  m_RECORD_LENGTH["A", 2] = 42
  m_RECORD_LENGTH["S", 2] = 10
  m_RECORD_LENGTH["E", 2] = 33
  m_RECORD_LENGTH["X", 2] = 24
  m_RECORD_LENGTH["P", 2] = 50
  m_RECORD_LENGTH["B", 2] = 18
}

#-----------------------------------------------------------------------------
# data format
#-----------------------------------------------------------------------------

# is string s a valid ticker?
# note: {n,m} regex pattern is not available in posix awk
function is_valid_ticker(s)
{
  return toupper(s) ~ /^[A-Z][A-Z][A-Z][A-Z][A-Z]?[A-Z]?$/
}

# time string (e.g., "07:12:58") from an island timestamp value (milliseconds
#  since midnight Eastern Time)
function itch_timestamp_to_time(t,
  h, m, s) 
{
  t = int(t/1000)
  s = "" t % 60
  t = int(t/60)
  m = "" t % 60
  h = "" int(t/60)
  if (length(h) == 1) {
    h = "0" h
  }
  if (length(m) == 1) {
    m = "0" m
  }
  if (length(s) == 1) {
    s = "0" s
  }
  return h ":" m ":" s
}


#-----------------------------------------------------------------------------
# get data from an ITCH file
#-----------------------------------------------------------------------------

# Return the version of ITCH data, or zero. Emit a message when version 2
# is detected.
function probe_itch_version(\
  version)
{
  version = 0
  if (_test_in(8, 1, m_RECORD_TYPES)) {
    version = 1
  } else if (_test_in(9, 1, m_RECORD_TYPES)) {
    version = 2
  }
  file_check(version == 1 || version == 2,
      "Unable to detect the version of ITCH data")
  
  printk_if(version == 2,
    "ITCH v2 uses rounded prices, which will likely trigger errors")

  return version
}

# Extract ISO date from the current ITCH filename, where a filename is
# assumed to start with a "S", followed by a date in mmddyy format, followed
# by a non digit character. Return a null string if a valid date cannot be 
# extracted.
# e.g. "S030800-v2.txt" => "2020-03-08"
function get_day_from_itch_filename(filepath,
  filename, yyyy, yy, dd, mm, datepart, day)
{
  filename = get_filename(filepath)
  match(filename, /^S[0-9][0-9][0-9][0-9][0-9][0-9][^0-9]/)
  if (!file_check(RLENGTH != -1,
      "cannot extract day from ITCH filename")) {
    return ""
  }

  datepart = substr(filename, RSTART+1, RLENGTH-2)
  yy = substr(datepart, 5, 2)
  dd = substr(datepart, 3, 2)
  mm = substr(datepart, 1, 2)
  yyyy = (yy > 50 ? "19" : "20") yy
  day = yyyy "-" mm "-" dd
  # TODO: test the date is valid
  return day
}

function get_itch_price_precision(day, version)
{
  assert(version == 1 || version == 2, "unknown ITCH version")
  return (version == 1 || day < "2000-07-03" ? 8 : 4)
}

# extract itch data from the current record
# this data structure is used in itch.awk:new_order_from_record(R)
function get_itch_record(R, day, version,
  type)
{
  R["timestamp"] = _get_TimeStamp(version)
  R["day"] = day

  type = _get_MessageType(version)
  R["type"] = type

  # start and end messages
  if (type == "S") {
    R["system"] = _get_EventCode(version)
  }

  # stock ticker
  if (index("AP", type)) {
    R["ticker"] = _get_Stock(version)
  }

  # order reference, number of shares
  if (index("APEX", type)) {
    R["order"] = _get_OrderReferenceNumber(version)
    R["shares"] = _get_Shares(version, type)
  }

  if (index("AP", type)) {
    R["bs"] = _get_BuySellIndicator(version)
    R["price"] = _get_Price(version, day)
  }

  if (type == "A") {
    R["display"] = _get_Display(version)
    R["visibility"] = "V"
  }

  if (type == "P") {
    R["display"] = " "
    R["visibility"] = "H"
  }

  if (index("PEB", type)) {
    R["match"] = _get_MatchNumber(version, type)
  }
}

#-----------------------------------------------------------------------------
# private functions: extract ITCH fields from $0
#-----------------------------------------------------------------------------

#
# All the following functions assume (version != 0)
#

function _get_MessageType(version,
  p, v)
{
  p = (version == 1 ? 8 : 9)
  v = _get_in(p, 1, m_RECORD_TYPES)
  if (index(m_RECORD_TYPES, v)) {
    file_check(length($0) == m_RECORD_LENGTH[v, version],
      "wrong message size:\n" $0)
  }
  return v
}

# Return the time in milliseconds past midnight Eastern Time.
function _get_TimeStamp(version,
  c, v)
{
  c = (version == 1 ? 7 : 8)
  v = _get_num(1, c) + 0
  if (version == 1)
    v *= 10
  return v + 0
}

# Return an order reference as a number to check that order numbers are
#  always increasing within each day.
function _get_OrderReferenceNumber(version,
  p, v)
{
  p = (version == 1 ? 9 : 10)
  v = _get_num(p, 9)
  return v + 0
}

function _get_EventCode(version,
  p, v)
{
  p = (version == 1 ? 9 : 10)
  v = _get_in(p, 1, "SE")
  return v
}

function _get_BuySellIndicator(version,
  p, v)
{
  p = (version == 1 ? 18 : 19)
  v = _get_in(p, 1, "BS")
  return v
}

# Is this order displayed in the Nasdaq quote?
# Y: yes
# S: no ("Subscriber Only")
# L: latent order (undocumented)
function _get_Display(version,
  p, v)
{
  p = (version == 1 ? 54 : 42)
  v = _get_in(p, 1, "YSL")
  return v
}

function _get_Stock(version,
  p, v)
{
  p = (version == 1 ? 28 : 26)
  v = _get(p, 6)
  return trim(v)
}

# return the price as a floating point value
# Note: starting July 3, 2000, there is no way to map ITCH-v2 prices
# (e.g. 109660) into ITCH-v1 prices (e.g. 10.1234567800), as v2-to-v1 is not
# injective: for instance,
# S010201-v2 price 109660 maps both into 14.9960000000 (line 145165) *and*
# into 14.9960937500 (line 141727) in S010201-v1
function _get_Price(version, day,
  p, c, v, v_dot)
{
  p = (version == 1 ? 34 : 32)
  c = (version == 1 ? 20 : 10) # e.g. 101234 (not decimal dot, 4 dec digits)
  v = _get_num(p, c)

  if (version == 1) {
    if (day < "2000-07-03") {
      file_check(v*256 == int(v*256), "price not on the 1/256 grid: " v)
    }
  } else {
    v_dot = substr(v, 1, length(v) - 4) "." right(v, 4)
    if (day < "2000-07-03") {
      # recover 1/256 price from a 4-digit price
      v = round(v*256/10000, 0)/256
    } else {
      # insert the decimal dot
      v = substr(v, 1, length(v) - 4) "." right(v, 4)
    }
  }

  # now return v as a floating point value; as this value may end up being
  # rounded, a function to convert back a price into a string is
  # provided by this module

  return v + 0
}


# return the volume as a integer value
function _get_Shares(version, type,
  p, c, v)
{
  if ((type == "A") || (type == "P"))
    p = (version == 1 ? 19 : 20)
  else
  if (type == "E")
    p = (version == 1 ? 18 : 19)
  else
  if (type == "X")
    p = (version == 1 ? 18 : 20)
  c = (version == 1 ? 9 : 6)
  v = _get_num(p, c) + 0
  return v + 0
}


function _get_MatchNumber(version, type,
  p, v)
{
  if (type == "P") {
    p = (version == 1 ? 54 : 42)
  } else if (type == "E") {
    p = (version == 1 ? 27 : 25)
  } else if (type == "B") {
    p = (version == 1 ? 9 : 10)
  }
  v = _get_num(p, 9)
  return v + 0
}

#-----------------------------------------------------------------------------
# private functions: extract data from $0
#-----------------------------------------------------------------------------

function _get(start, num) 
{
  file_check(length($0) >= start + num - 1, "ITCH record too short\n" $0)
  return substr($0, start, num)
}

function _get_in(start, num, str,
  v) 
{
  v = _get(start, num)
  file_check(index(str, v), "unexpected value: \"" v "\"\n" $0)
  return v
}

function _test_in(start, num, str,
  v, is_in)
{
  v = _get(start, num)
  is_in = (index(str, v) != 0)
  return is_in
}

function _get_num(start, num,
  v)
{
  v = _get(start, num)
  file_check(v ~ /^ *[0-9]+(\.[0-9]+)? *$/, 
      "positive number expected: \"" v "\"\n" $0)
  return v
}
