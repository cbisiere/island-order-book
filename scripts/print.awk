# ----------------------------------------------------------------------------
#
#  Project : ITCH data
#  Author  : Christophe Bisière
#  Module  : output data files and book trace
#
# ----------------------------------------------------------------------------

# -----------------------------------------------------------------------
#  tab-separated pieces of data
# -----------------------------------------------------------------------

# return essential context data: datetime and stock ticker,
#  or a header line if head is true
function _get_minimal_context_data(R, head,
  ticker, str)
{
  if (head) {
    return "day" "\t" "time" "\t" "mtime" "\t" "ticker"
  }

  ticker = R["ticker"]

  str = \
      book_day(ticker) "\t" \
      book_time(ticker) "\t" \
      book_mtime(ticker) "\t" \
      R["ticker"]

  return str
}

# get contextual book state data before the event (spread),
#  or a header line if head is true
function _get_book_state_data(R, head,
  ticker, str)
{
  if (head) {
    return "best_bid" "\t" "best_ask" "\t" "best_bid_q" "\t" "best_ask_q"
  }

  ticker = R["ticker"]

  str = \
      _price_as_data(R["best_bid"]) "\t" \
      _price_as_data(R["best_ask"]) "\t" \
      _val(R, "best_bid_q") "\t" \
      _val(R, "best_ask_q")

  return str
}

# get broken trade data,
#  or a header line if head is true
function _get_broken_trade_data(R, head,
  str)
{
  if (head) {
    return "match"
  }

  str = R["match"]

  return str
}

# get spread data,
#  or a header line if head is true
function _get_current_spread_data(R, head,
  ticker, str)
{
  if (head) {
    return "best_bid" "\t" "best_ask" "\t" "best_bid_q" "\t" "best_ask_q"
  }

  ticker = R["ticker"]

  str = \
      _price_as_data(best_price(R["ticker"], "B")) "\t" \
      _price_as_data(best_price(R["ticker"], "S")) "\t" \
      best_quantity(R["ticker"], "B") "\t" \
      best_quantity(R["ticker"], "S")

  return str
}

# get event data
#  or a header line if head is true
function _get_event_data(R, head,
  str)
{
  if (head) {
    str = "event" "\t" "order" "\t" "bs" "\t" "shares" "\t" "where" "\t" \
        "price" "\t" "visibility" "\t" "display" "\t" "match" "\t" \
        "sign" "\t" "is_marginal" "\t" "is_fully_executed"
    return str
  }

  str = \
      _val(R, "event") "\t" \
      _val(R, "order") "\t" \
      _val(R, "bs") "\t" \
      _val(R, "shares") "\t" \
      _val(R, "where") "\t" \
      _price_as_data(R["price"]) "\t" \
      _val(R, "visibility") "\t" \
      _val(R, "display") "\t" \
      _val(R, "match") "\t" \
      _val(R, "sign") "\t" \
      _val(R, "is_marginal") "\t" \
      _val(R, "is_fully_executed")

  return str
}

# -----------------------------------------------------------------------
#  tab-separated data rows
# -----------------------------------------------------------------------

# Get a best quote row,
#  or a header line if head is true.
function get_best_quote_row(R, head,
  str)
{
  str = \
      _get_minimal_context_data(R, head) "\t" \
      _get_current_spread_data(R, head)

  return str
}


# Get an event row,
#  or a header line if head is true.
function get_event_row(R, head,
  str)
{
  str = \
      _get_minimal_context_data(R, head) "\t" \
      _get_book_state_data(R, head) "\t" \
      _get_event_data(R, head)

  return str
}

# Get a broken trade row,
#  or a header line if head is true.
function get_broken_trade_row(R, head,
  str)
{
  str = \
      _get_minimal_context_data(R, head) "\t" \
      _get_broken_trade_data(R, head)

  return str
}


# Get a book row record, with quantities agreggated for at each price level,
#  or a header line if head is true.
function get_book_row(R, head,
  str, ticker, side, label, d, r, i, j, p, n, sum_q, PP, QQ)
{
  str = _get_minimal_context_data(R, head)

  ticker = R["ticker"]

  label["B"] = "bid"
  label["S"] = "ask"

  side[1] = "B"
  side[2] = "S"

  # volume and price
  for (i = 1; i<=2; i++) {
    d = side[i]
    r = book_head(ticker, d)
    p = 0
    n = 0
    sum_q = 0

    QQ = ""
    PP = ""

    while ((r != g_NULL_r) && (n < P_BOOK_LEVELS)) {
      if (order_is_visible(r) && (order_price(r) != p)) {
        n++
        p = order_price(r)
        sum_q += book_volume_at_price(ticker, d, p)

        QQ = QQ "\t" (head ? label[d] "_q_" n  : book_volume_at_price(ticker, d, p))
        PP = PP "\t" (head ? label[d] "_p_" n  : _price_as_data(p))
      }
      r = next_order(r)
    }
    # complete empty columns with missing values
    for (j = n+1; j <= P_BOOK_LEVELS; j++) {
      QQ = QQ "\t" (head ? label[d] "_q_" j  : g_NULL_d)
      PP = PP "\t" (head ? label[d] "_p_" j  : g_NULL_d)
    }

    str = str PP QQ
    # volume not shown in this data and total volume by book side
    str = str "\t" (head ? label[d] "_q_other"  : book_volume(ticker, d) - sum_q)
    str = str "\t" (head ? label[d] "_q_total"  : book_volume(ticker, d))
  }

  return str
}


# -----------------------------------------------------------------------
#                               Trace
# -----------------------------------------------------------------------

function get_event_trace(R,
  str)
{
  str = \
      _trace(R, "ticker") \
      _trace(R, "day") \
      _trace(R, "timestamp") \
      _trace(R, "event") \
      _trace(R, "order") \
      _trace(R, "is_new_ref") \
      _trace(R, "bs") \
      _trace(R, "shares") \
      _trace(R, "where") \
      _trace_price(R, "price") \
      _trace(R, "visibility") \
      _trace(R, "display") \
      _trace(R, "match") \
      _trace(R, "sign") \
      _trace(R, "is_marginal") \
      _trace(R, "is_fully_executed")

  return str
}

# Return a string to display the value of a price field in a record, 
#  if the field is not empty.
function _trace_price(R, field)
{
  return _trace_value(R, field, 1)
}

# Return a string to display the value of a field in a record, 
#  if the field is not empty.
function _trace(R, field)
{
  return _trace_value(R, field, 0)
}

# Return a string to display the value of a field in a record, 
#  if the field is not empty.
function _trace_value(R, field, is_price,
  fmt, str)
{
  if (!(field in R)) {
    return ""
  }
  fmt = "%-18s : %s\n"
  str = (is_price ? _price_as_data(R[field]) : R[field])
  return sprintf(fmt, field, str)
}


#
# print book of stock s
#
function get_trace_book(R,
  out, ticker, w, fmt, side_sep, sep, bb, ba, bbs, bas, bbq, baq, c, b, a, i, strb, stra, hb, ha, Top)
{
  out = ""

  ticker = R["ticker"]

  w = 35 # width of one side of the book
  fmt = "%" w "s"
  side_sep = " | "
  sep = dup("-", w + length(side_sep) + w)

  out = out ticker \
      " " book_day(ticker) \
      " " timestamp_for_display(book_timestamp(ticker)) "\n"
  out = out sep "\n"

  bb = best_price(ticker, "B")
  ba = best_price(ticker, "S")
  bbq = best_quantity(ticker, "B")
  baq = best_quantity(ticker, "S")

  if (bb != g_NULL_d)
    bb = trim(_price_to_string(bb))
  if (ba != g_NULL_d)
    ba = trim(_price_to_string(ba))

  out = out ticker " :  " bb "/" ba " (" bbq "/" baq ")" "\n"

  out = out sep "\n"

  c = 0
  hb = 0
  ha = 0
  b = book_head(ticker, "B")
  a = book_head(ticker, "S")
  while (b != g_NULL_r || a != g_NULL_r) {
    c++
    if (!P_MAX_DISPLAY || c <= P_MAX_DISPLAY) {
      strb = (b == g_NULL_r ? "" : (c == P_MAX_DISPLAY && next_order(b) != g_NULL_r ? "..." : _get_trace_book_row(b)))
      stra = (a == g_NULL_r ? "" : (c == P_MAX_DISPLAY && next_order(a) != g_NULL_r ? "..." : _get_trace_book_row(a)))
      out = out sprintf(fmt side_sep fmt "\n", strb, stra)
    }
    if (b != g_NULL_r)
      hb++
    if (a != g_NULL_r)
      ha++
    if (b != g_NULL_r)
      b = next_order(b)
    if (a != g_NULL_r)
      a = next_order(a)
  }
  out = out sep "\n"
  out = out sprintf(fmt, "(" hb " orders)") dup(" ", length(side_sep)) sprintf(fmt, "(" ha " orders)") "\n"

  return out
}

# Return a string containing a book line to display in a book trace.
function _get_trace_book_row(r,
  str)
{
  str = _price_to_string(order_price(r))
  str = sprintf("[%+9s %c] %6d %+12s", r, order_display(r), \
      order_remaining_size(r), str)
  return str
}

# Return a (possibli NULL) price as a string.
function _price_to_string(p)
{
  return (p == g_NULL_d ? g_NULL_d : price_for_display(p))
}

# Return a string for price p suitable for a value in a data file:
#  a floating point value without unnecessary trailing zeros.
function _price_as_data(p,
  str)
{
  if (p == g_NULL_d)
    return g_NULL_d

  # recover the original value
  str = price_for_display(p)
  # drop all trailing zeros but one
  sub(/0+$/, "", str)
  sub(/\.$/, ".0", str)

  return str
}

# Return a value from the record R, to be part of a data file.
function _val(R, field)
{
  if (field in R) {
    return R[field]
  }
  if (g_FIELD_TYPE[field] == "string") {
    return g_NULL_s
  }
  return g_NULL_d
}


# Return a time value w/ ms (e.g. "9:30:01.090") from a timestamp, that is
#  a number a ms since midnight.
function timestamp_for_display(t)
{
  return itch_timestamp_to_time(t) "." sprintf("%03d", t % 1000)
}
