# ----------------------------------------------------------------------------
#
#  Project : ITCH data
#  Author  : Christophe Bisière
#  Module  : book building and walking
#
# ----------------------------------------------------------------------------

BEGIN {

  # Island 2000-2001 decimalization plan:
  # https://web.archive.org/web/20011110062129/http://www.island.com/decimals/DecimalFinal.htm
  # https://web.archive.org/web/20011212072922/http://www.island.com/decimals/faq.htm
  # https://web.archive.org/web/20000815061854/http://www.island.com:80/pdfs/Decimalization%20White%20Paper.pdf

  # price denominators defining tick sizes; current tick size
  #  depends on the time period and on the stock; during a certain time
  #  two tick sizes were allowed at the same time
  # data structure to be used in a "for (k in m_TICK)" loop
  m_TICK[256] = 1 # "fractional" price
  m_TICK[1000] = 1 # "decimal" price

  # start of the decimalization plan: July 3, 2000
  # https://web.archive.org/web/20011212072922/http://www.island.com/decimals/faq.htm#What%20is%20Island?s%20Decimalization%20Program?
  #  "Beginning July 3, 2000, consistent with the U.S. Congress’s deadline for
  #  conversion to decimals for trading of stocks, Island began accepting and
  #  displaying orders in full decimal prices."
  # https://web.archive.org/web/20011221121345/http://www.island.com/pressroom/releases/041900.htm
  # https://web.archive.org/web/20011027125014/http://island.com/pressroom/releases/062900.htm
  m_MARKET_START_DAY = "2000-07-03"

  # pilots for 2001 1/1000 grid follows NASDAQ switch to 1 cent grid

  # https://web.archive.org/web/20010417041455/http://www.nasdaqtrader.com/Trader/News/headtraderalerts/hta2001-31.stm
  m_PILOT_DAY_1 = "2001-03-05"
  m_PILOT_1 = " TEST TESTA TESTB "

  # https://web.archive.org/web/20010417040253/http://www.nasdaqtrader.com/Trader/News/headtraderalerts/hta2001-40.stm
  m_PILOT_DAY_2 = "2001-03-12"
  m_PILOT_2 = " BRCD CMRC CMTN COCBF CREE EXTR IDTI INKT MUSE NEWP OPWV " \
    "RBAK RIMM RMBS VERT "

  # https://web.archive.org/web/20010417041501/http://www.nasdaqtrader.com/Trader/News/headtraderalerts/hta2001-44.stm
  # https://web.archive.org/web/20010417034753/http://www.nasdaqtrader.com/Trader/News/headtraderalerts/hta2001-47.stm
  m_PILOT_DAY_3 = "2001-03-26"
  m_PILOT_3 = " AAPL AATK ADBE AICX AMZN ARDNA ASGR ATGN ATHM ATHY AVEA " \
    "AVNX BFAM BOGN BOSC BOYL BRCM BRND BTGC BUCA BULL BUSY BUSYW CAFI " \
    "CAIS CALY CBIN CBLT CERT CFCM CHDN CHEL CMGI CMSB CMVT CNDL COOP " \
    "CPRT CRRC CRTQ CTAS CURE CVNS CWTR CXSN CYGN CYMI CYTR DGLV DGLVZ " \
    "DMIF DPMI DRXR DVIN ECCS ECGI EDGR EONC ERIE ESITZ ESRX EXLN FARL " \
    "FBAN FBANP FFEX FLIC FMBI FNBF FRTG FSTR FUSA GENI GENZ GNTA GRCO " \
    "GSTRF1 GZBX GZMO HAVNP HCFC HERBA HERBB HFGI HFWA HIFN HIHO HMLD " \
    "HOLL ICTS IENT ILFO IMON INBI INCY INEI INRG IVGN JAWZ JLMI JNPR " \
    "JUDG KELYA KELYB KTII LARK LAWS LCTO LIQB LMLP MAXM MAXMW MBWM " \
    "MBWMP MCAF MCHM MDRX MEGO METG MFNX MIGI MKSI MLNM MRKF MUEI MVBI " \
    "MVBIP MXIM NARA NASC NHCI NUAN NUFO NYCB NYHC OLDB OLGC OMNY ONSS " \
    "ONSSU ONSSW ORCL PDEX PMCS PRMO PROA PTMK PTMKW PURE PUREW PWER " \
    "QUST QUSTW RACN RACNW RCGI RDRT RHAT ROIX3 RSTR2 RZYM SEBL SEPR " \
    "SIDY SLTC SMCS SMDK SNCI SNKI SQSW SSCC SSCCP SSFC SSTI STBA STXN " \
    "SUNW SWWC TDDD TEKS TEKSP TEKSW TRNI TRPS TUTR UAXS UNFI VMTI VRTL " \
    "VRTS VTRAO VVUS WRLD WYPT XRIT XYBR YORK ZION ZMBA "

  # the day all stocks went decimal-only
  m_MARKET_SWITCH_DAY = "2001-04-09"
}

#-----------------------------------------------------------------------------
# market state
#-----------------------------------------------------------------------------

# Reset the market: session, books, orders, etc.
function reset_market_state()
{
  # trading session: state, price precision
  delete m_SESSION

  # reference-to-ticker table: ticker and first record number
  delete m_REFS
  delete m_REFS_LOC

  # match-to-ticker table
  delete m_MATCHES


  # data structure maintained for target tickers only:

  # ticker-indexed data structures
  delete m_GRID
  delete m_ORDERS
  delete m_LAST_REC
  delete m_CLOCK
  delete m_BH
  delete m_BQ
  delete m_BV

  # reference-indexed data structures
  delete m_C
  delete m_A
  delete m_T
  delete m_S
  delete m_D
  delete m_Q
  delete m_P
  delete m_Y
  delete m_V
  delete m_Next
  delete m_Prev
}

# Return the market state as a giant string.
function market_state_as_string()
{
  return  \
      array_as_string("m_SESSION", m_SESSION) \
      array_as_string("m_REFS", m_REFS) \
      array_as_string("m_REFS_LOC", m_REFS_LOC) \
      array_as_string("m_MATCHES", m_MATCHES) \
      array_as_string("m_GRID", m_GRID) \
      array_as_string("m_CLOCK", m_CLOCK) \
      array_as_string("m_LAST_REC", m_LAST_REC) \
      array_as_string("m_ORDERS", m_ORDERS) \
      array_as_string("m_BH", m_BH) \
      array_as_string("m_BQ", m_BQ) \
      array_as_string("m_BV", m_BV) \
      array_as_string("m_C", m_C) \
      array_as_string("m_A", m_A) \
      array_as_string("m_T", m_T) \
      array_as_string("m_S", m_S) \
      array_as_string("m_D", m_D) \
      array_as_string("m_Q", m_Q) \
      array_as_string("m_P", m_P) \
      array_as_string("m_Y", m_Y) \
      array_as_string("m_V", m_V) \
      array_as_string("m_Next", m_Next) \
      array_as_string("m_Prev", m_Prev)
}


#-----------------------------------------------------------------------------
# trading session
#-----------------------------------------------------------------------------

function session_start()
{
  file_check(!("state" in m_SESSION), "wrong sequence of system messages")
  m_SESSION["state"] = 1
}

function session_event()
{
  file_check(m_SESSION["state"] == 1, "market is not open")
}

function session_end()
{
  file_check(m_SESSION["state"] == 1, "wrong sequence of system messages")
  m_SESSION["state"] = 2
}

function session_must_be_complete()
{
  file_check(m_SESSION["state"] == 2,
      "market open/close sequence absent or incomplete")
}

function session_is_complete()
{
  return m_SESSION["state"] == 2
}

#-----------------------------------------------------------------------------
# price precision
#-----------------------------------------------------------------------------

function set_price_precision(n)
{
  assert(!("precision" in m_SESSION), "price precision already set")
  m_SESSION["precision"] = n
}

function price_for_display(p)
{
  return sprintf("%." _get_price_precision() "f", p)
}

function _get_price_precision()
{
  assert("precision" in m_SESSION, "price precision not set yet")
  return m_SESSION["precision"]
}

#-----------------------------------------------------------------------------
# book
#-----------------------------------------------------------------------------

# Initialize per-ticker arrays:
#  m_ORDERS[s]: counter of order arrivals
#  m_GRID[s, k]: tick sizes, as allowed denominator of price increments
#  m_BH[s, d], m_BQ[s, d]: book head, book queue
#  m_BV[s, d, p]: visible volume on the book at different prices
#  m_BV[s, d]: total visible volume on the book
#  m_CLOCK[s, x]: clock data (last event on this book)
function new_book(s, day)
{
  _reset_last_record(s)
  m_ORDERS[s] = 0

  _get_price_grid(s, day, m_GRID)

  m_BH[s, "B"] = g_NULL_r
  m_BH[s, "S"] = g_NULL_r

  m_BQ[s, "B"] = g_NULL_r
  m_BQ[s, "S"] = g_NULL_r

  m_BV[s, "B"] = 0
  m_BV[s, "S"] = 0

  m_CLOCK[s, "day"] = day
  m_CLOCK[s, "timestamp"] = 0
  m_CLOCK[s, "time"] = "00:00:00"
  m_CLOCK[s, "mtime"] = 0
}

function has_book(s)
{
  return (s in m_ORDERS)
}

#-----------------------------------------------------------------------------
# book walking
#-----------------------------------------------------------------------------

# Order reference of order of highest priority on side d.
function book_head(s, d) 
{
  return m_BH[s, d]
}

function next_order(r)
{
  return m_Next[r]
}

#-----------------------------------------------------------------------------
# book volume
#-----------------------------------------------------------------------------

# Return the visible volume on side d.
function book_volume(s, d)
{
  return m_BV[s, d]
}

# Return the visible volume on side d at price level p.
function book_volume_at_price(s, d, p)
{
  return m_BV[s, d, p]
}

#-----------------------------------------------------------------------------
# book best quotes
#-----------------------------------------------------------------------------

function best_price(s, d,
    h)
{
  h = m_BH[s, d]
  if (h == g_NULL_r) {
    return g_NULL_d
  }
  return m_P[h]
}

function best_quantity(s, d,
    h)
{
  h = m_BH[s, d]
  if (h == g_NULL_r) {
    return 0
  }
  return 	m_BV[s, d, m_P[h]]
}

#-----------------------------------------------------------------------------
# book clock
#-----------------------------------------------------------------------------

function book_day(s)
{
  return m_CLOCK[s, "day"]
}

function book_timestamp(s)
{
  return m_CLOCK[s, "timestamp"]
}

function book_time(s)
{
  return m_CLOCK[s, "time"]
}

function book_mtime(s)
{
  return m_CLOCK[s, "mtime"]
}

# Update "last event time" (in ms since midnight).
function update_book_clock(s, t,
  prev_t)
{
  prev_t = m_CLOCK[s, "timestamp"]

  # timestamps, over the same day and at market level, must be (weakly)
  #  incresing
  ticker_check(s, t >= prev_t,
      "record not properly sorted on time")

  m_CLOCK[s, "timestamp"] = t
  m_CLOCK[s, "time"] = itch_timestamp_to_time(t)
  m_CLOCK[s, "mtime"] = t % 1000
}

#-----------------------------------------------------------------------------
# last record
#-----------------------------------------------------------------------------

# Copy in R the m_LAST_REC fields available for ticket s.
function get_last_record(s, R,
  field, i) 
{
  delete R
  for (field in g_FIELD_TYPE) {
    i = s g_SUBSEP field
    if (i in m_LAST_REC) {
      R[field] = m_LAST_REC[i]
    }
  }
}

# Copy in m_LAST_REC the R fields available for ticket s.
function set_last_record(s, R,
  field) 
{
  _reset_last_record(s)
  for (field in R) {
    m_LAST_REC[s, field] = R[field]
  }
}

function _reset_last_record(s,
  field, i) 
{
  for (field in g_FIELD_TYPE) {
    i = s g_SUBSEP field
    if (i in m_LAST_REC) {
      delete m_LAST_REC[i]
    }
  }
}


#-----------------------------------------------------------------------------
# match numbers
#-----------------------------------------------------------------------------

function new_match(m, s)
{
  ticker_check(s, !match_is_known(m), "match number " m " already exists")
  m_MATCHES[m] = s
}

function match_is_known(m)
{
  return m in m_MATCHES
}

function match_to_ticker(m)
{
  file_check(match_is_known(m), "unknown match number: " m)

  return m_MATCHES[m]
}

#-----------------------------------------------------------------------------
# order reference numbers of all orders in the ITCH file
#-----------------------------------------------------------------------------

function new_reference(r, s)
{
  ticker_check(s, !reference_is_known(r),
      "reference " r " already exists: " array_element(m_REFS, r,"") \
      " on line " array_element(m_REFS_LOC, r, "")) # makes lint quiet
  m_REFS[r] = s
  m_REFS_LOC[r] = FNR
}

function reference_is_known(r)
{
  return r in m_REFS
}

function reference_to_ticker(r)
{
  file_check(reference_is_known(r), "unknown reference: " r)

  return m_REFS[r]
}

#-----------------------------------------------------------------------------
# limit orders of target tickers
#-----------------------------------------------------------------------------

#
# Create a new limit order (not yet in the book: m_A[r] = 0).
# it is assumed that the order reference has already been declared with
#  new_reference()
#
# Note: for an hidden order, "time" is the time of first execution,
#
function new_order_from_record(R,
  r, s, on_grid)
{
  r = R["order"]
  s = R["ticker"]

  ticker_check(s, reference_to_ticker(r) == s,
      "order reference used for a different ticker")

  ticker_check(s, _price_is_on_grid(R["price"], m_GRID, s),
      "price not on grid")

  m_C[r] = 1   # created
  m_A[r] = 0   # alive (== in the book, with a positive quantity)
  m_T[r] = R["timestamp"]   # time of arrival (or first execution for hidden orders)
  m_S[r] = R["ticker"]   # stock ticker
  m_D[r] = R["bs"]
  m_Q[r] = R["shares"]
  m_P[r] = R["price"]
  m_Y[r] = R["display"]
  m_V[r] = R["visibility"]

  m_Prev[r] = g_NULL_r
  m_Next[r] = g_NULL_r
}

# For the sake of memory space, we drop all data structure
# for this order r. It implies that we will not be able to
# detect any (forbiden) futur reference to r.
function _delete_order(r) {

  delete m_C[r]
  delete m_A[r]
  delete m_T[r]
  delete m_S[r]
  delete m_D[r]
  delete m_Q[r]
  delete m_P[r]
  delete m_Y[r]
  delete m_V[r]
  delete m_Next[r]
  delete m_Prev[r]
}

function order_remaining_size(r)
{
  return m_Q[r]
}

function order_bs(r)
{
  return m_D[r]
}

function order_price(r)
{
  return m_P[r]
}

function order_display(r)
{
  return m_Y[r]
}

function order_visibility(r)
{
  return m_V[r]
}

function order_is_visible(r)
{
  return m_V[r] == "V"
}

# Return true if an order has the highest priority in the book.
function order_is_book_head(r)
{
  ticker_check(m_S[r], m_A[r] == 1, "order not in the book: " r)

  return m_Prev[r] == g_NULL_r
}

# Return true if an order is marginal.
# An order is marginal if is has the lowest time priority amongst all _visible_
# orders at the same price limit.
# Note: the condition below is correct since we only stores visible orders in
# the book.
function order_is_marginal(r)
{
  ticker_check(m_S[r], m_A[r] == 1, "order not in the book: " r)

  return (m_Next[r] == g_NULL_r || m_P[m_Next[r]] != m_P[r])
}

# Return the location of an order  with respect to the current best quotes
#  in the book.
function order_location(r,
    bb, ba, where, d, p)
{
  where = g_NULL_s
  d = m_D[r]
  p = m_P[r]
  bb = best_price(m_S[r], "B")
  ba = best_price(m_S[r], "S")

  if (d == "B") {
    if (ba != g_NULL_d && p >= ba) {
      where = "marketable"
    } else if (bb == g_NULL_d || bb < p) {
      where = "within"
    } else if (p == bb) {
      where = "at"
    } else if (p < bb) {
      where = "away"
    }
  } else if (d == "S") {
    if (bb != g_NULL_d && p <= bb) {
      where = "marketable"
    } else if (ba == g_NULL_d || p < ba) {
      where = "within"
    } else if (p == ba) {
      where = "at"
    } else if (p > ba) {
      where = "away"
    }
  }

  return where
}

# Insert a new _visible_ order in the book.
function insert_order_in_book(r,
  d, q, s, p, y, h, u)
{
  s = m_S[r]

  ticker_check(s, m_C[r] == 1, "cannot insert an order that does not exist: " r)
  ticker_check(s, m_A[r] != 1, "order is already in the book: " r)

  m_A[r] = 1

  d = m_D[r]
  q = m_Q[r]
  p = m_P[r]

  # stats

  m_ORDERS[s]++
  add_to_array_element(m_BV, s g_SUBSEP d, q)
  add_to_array_element(m_BV, s g_SUBSEP d g_SUBSEP p, q)

  # insert r into the book

  h = m_BH[s, d]
  u = m_BQ[s, d]

  # Case 1: side "d" of the book is empty

  if (h == g_NULL_r) {
    m_BH[s, d] = r
    m_BQ[s, d] = r
    m_Prev[r] = g_NULL_r
    m_Next[r] = g_NULL_r
  }

  # Case 2: order within the best quotes

  else if (d == "B" ? p > m_P[h] : p < m_P[h]) {
    m_BH[s, d] = r
    m_Prev[r] = g_NULL_r
    m_Next[r] = h
    m_Prev[h] = r
  }

  # Case 3: worst price limit

  else if (d == "B" ? p <= m_P[u] : p >= m_P[u]) {
    m_BQ[s, d] = r
    m_Prev[r] = u
    m_Next[r] = g_NULL_r
    m_Next[u] = r
  }

  # Case 4: common case (order in the middle part of the book)

  else {
    while((d == "B" ? p <= m_P[h] : p >= m_P[h])) {
      h = m_Next[h]
    }
    m_Next[r] = h
    m_Prev[r] = m_Prev[h]
    m_Prev[h] = r
    m_Next[m_Prev[r]] = r
  }
}

# Decrease the quantity for order r (as the result of an execution or a
# cancellation) and update the book.
function decrease_order_size(r, q,
    s, d, p)
{
  s = m_S[r]
  d = m_D[r]
  p = m_P[r]

  ticker_check(s, m_C[r] == 1, "cannot update an order that does not exist: " r)
  ticker_check(s, m_A[r] == 1, "cannot update an order not in the book: " r)

  m_Q[r] -= q
  ticker_check(s, m_Q[r] >= 0, "negative quantity")

  m_BV[s, d, p] -= q
  ticker_check(s, m_BV[s, d, p] >= 0, "negative cumulated quantity")
  if (m_BV[s, d, p] == 0) {
    delete m_BV[s, d, p]
  }

  m_BV[s, d] -= q
  ticker_check(s, m_BV[s, d] >= 0, "negative total cumulated quantity")

  # order remaining quantity reaches zero: drop the order
  if (m_Q[r] == 0) {
    if (m_BH[s, d] == r) {
      m_BH[s, d] = m_Next[r]
    }
    if (m_BQ[s, d] == r) {
      m_BQ[s, d] = m_Prev[r]
    }
    if (m_Next[r] != g_NULL_r) {
      m_Prev[m_Next[r]] = m_Prev[r]
    }
    if (m_Prev[r] != g_NULL_r) {
      m_Next[m_Prev[r]] = m_Next[r]
    }

    # take note that the order is not in the book anymore
    m_A[r] = 0

    # however, for the sake of memory space, we drop all data structure
    # for this order; the reference still exists in m_REFS
    _delete_order(r)
  }
}

#-----------------------------------------------------------------------------
# price grid
#
# a price grid is a set of denominators stored as indexes in an array,
#  e.g. if G[256]==1 and G[1000]==1, both are allowed as denominators, that
#  is, a price can be multiple of 1/256 or 1/1000
# Note: an array is needed since Island used a "mixed grid" for a wwhile
#-----------------------------------------------------------------------------

# Set GR[s] to the price grid of stock s on a given day.
function _get_price_grid(s, day, GR,
  k)
{
  # reset tick size data for this stock
  for (k in m_TICK) {
      GR[s,k] = 0
  }

  if (day < m_MARKET_START_DAY) {
    GR[s,256] = 1
  } else if ((day >= m_PILOT_DAY_1) && index(" " s " ", m_PILOT_1) ||
    (day >= m_PILOT_DAY_2) && index(" " s " ", m_PILOT_2) ||
    (day >= m_PILOT_DAY_3) && index(" " s " ", m_PILOT_3) ||
    (day >= m_MARKET_SWITCH_DAY)) {
    GR[s,1000] = 1
  } else {
    # mixed environment during Island's Decimalization Program, from July
    # 2000 to March-April 2001
    GR[s,256] = 1
    GR[s,1000] = 1
  }
}

# Return true if price p is on at least one allowed price grid (that is,
#  an index in GR[s]).
function _price_is_on_grid(p, GR, s,
    on_grid, k)
{
  on_grid = 0
  for (k in m_TICK) {
    on_grid = on_grid || GR[s,k]==1 && _price_is_on_grid_denominator(p, k)
  }
  return on_grid
}

# Return true if the price p is on the price grid defined by denominator k.
# (e.g. on a 1/256 price increment for k=256)
function _price_is_on_grid_denominator(p, k)
{
  return p*k == int(p*k)
}
