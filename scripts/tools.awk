# ----------------------------------------------------------------------------
#
#  Project : ITCH data
#  Author  : Christophe Bisière
#  Module  : helpers
#
# ----------------------------------------------------------------------------

BEGIN {
  # exit state 
  # https://www.gnu.org/software/gawk/manual/html_node/Exit-Statement.html
  m_exit = 0

  # to keep track of output files
  delete m_OUT_FILES

  # log file group and default log file
  m_LOG = "LOG"
  m_log_filename = "/dev/sdtout"
}

#-----------------------------------------------------------------------------
#  exit state
#-----------------------------------------------------------------------------

# Exit and take notice.
function do_exit()
{
  m_exit = 1
  exit
}

# Erturn exit state.
function did_exit()
{
  return m_exit
}

#-----------------------------------------------------------------------------
#  output files
#-----------------------------------------------------------------------------

# Reset the whole file list.
function reset_output_file_list()
{
  delete m_OUT_FILES
}

# Print to file which belongs to a user-defined group.
function print_to_file_in_group(group, str, filename)
{
  print str > filename
  m_OUT_FILES[group, filename] = 1
}

# Append to file which belongs to a user-defined group.
function append_to_file_in_group(group, str, filename)
{
  print str >> filename
  m_OUT_FILES[group, filename] = 1
}

# Close all files in a user-defined group.
function close_files_in_group(group,
  i, arr)
{
  for (i in m_OUT_FILES) {
    split(i, arr, g_SUBSEP)
    if (arr[1] == group) {
      close(arr[2])
    }
  }
}

# Compress all files in a user-defined group.
function compress_files_in_group(group,
  i, arr)
{
  for (i in m_OUT_FILES) {
    split(i, arr, g_SUBSEP)
    if (arr[1] == group) {
      system("gzip -f " arr[2] " >/dev/null 2>&1")
    }
  }
}

#-----------------------------------------------------------------------------
#  errors and log
#-----------------------------------------------------------------------------

function set_log_filename(filename)
{
  m_log_filename = filename
}

function close_log()
{
  close_files_in_group(m_LOG, m_log_filename)
}

function writeln2log(msg) 
{
  append_to_file_in_group(m_LOG, msg, m_log_filename)
}

# Write to stderr and to the log file.
function writelnAndLog(msg) 
{
  write_to_stderr(msg)
  writeln2log(now() ": " msg)
}

# Log a message using an appropriate tag.
# Use g_* shadow fields, to keep gawk's linter happy. 
function printk(msg,
  tag) 
{
  tag = (g_file_context ? "[" g_filename ":" g_frn "] " : "")
  writelnAndLog(tag msg)
}

# Log a message if a condition is met.
function printk_if(cond, msg)
{
  if (cond) {
    printk(msg)
  }
}

#-----------------------------------------------------------------------------
#  numbers
#-----------------------------------------------------------------------------

function is_positive_integer(s) 
{
  return s ~ /^ *([1-9][0-9]*|0) *$/
}

# Round x to n decimal digits.
function round(x, n)
{
  return sprintf("%." n "f", x)
}

#-----------------------------------------------------------------------------
#  assert
#-----------------------------------------------------------------------------

function assert(cond, msg) 
{
  if (!cond) {
    printk("Fatal Error (bug): " msg)
    exit
  }
}

#-----------------------------------------------------------------------------
#  files
#-----------------------------------------------------------------------------

function get_filename(path,
  n, parts) 
{
  n = split(path, parts, "/")
  return parts[n]
}

function is_directory(path)
{
  return !system("test -d \"" path "\"")
}

#-----------------------------------------------------------------------------
#  string
#-----------------------------------------------------------------------------

function trim(str) 
{
  sub(/^ */, "", str)
  sub(/ *$/, "", str)
  return str
}

# right c chars of s
function right(s, c)
{
  return substr("" s, length("" s)-c+1)
}

function dup(str, n,  
  res, i)
{
  res = ""
  for (i=1; i<=n; i++) {
    res = res str
  }
  return res
}


#-----------------------------------------------------------------------------
#  array
#-----------------------------------------------------------------------------

# Return a string representation of an array.
# (For the sake of compatibility, gawk arrays-of-arrays are not supported.)
function array_as_string(ar_name, ar,
  str_ar, i, str_i)
{
  str_ar = ""
  for (i in ar) {
    str_i = i
    gsub(g_SUBSEP, ", ", str_i)
    str_ar = str_ar sprintf("%s[%s] = %s\n", ar_name, str_i, ar[i])
  }
  return str_ar
}

# Return an array element, or a default value if the index does not exist.
# Do not create any new element.
function array_element(arr, idx, default)
{
  if (idx in arr) {
    return arr[idx]
  }
  return default
}

# Add n to an array element, creating it if it does not exist.
# This keeps lint quiet.
function add_to_array_element(arr, idx, n)
{
  arr[idx] = array_element(arr, idx, 0) + n
}
