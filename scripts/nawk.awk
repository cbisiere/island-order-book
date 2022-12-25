# ----------------------------------------------------------------------------
#
#  Project : ITCH data
#  Author  : Christophe Bisière
#  Module  : nawk compatibility layer
#
# ----------------------------------------------------------------------------

function write_to_stderr(str)
{
  print str | "cat 1>&2"
}

# current local date and time in iso format,
#  e.g. "2021-12-29 23:43:24"
function now()
{
  return _command_output("date \"+%Y-%m-%d %H:%M:%S\"")
}

# command exec output
function _command_output(command,
  out)
{
  command | getline out
  close(command)
  return out
}
