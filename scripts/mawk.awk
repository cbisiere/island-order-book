# ----------------------------------------------------------------------------
#
#  Project : ITCH data
#  Author  : Christophe Bisière
#  Module  : mawk compatibility layer
#
# ----------------------------------------------------------------------------

function write_to_stderr(str)
{
  print_to_file_in_group(g_STD, str, "/dev/stderr")
}

# current local date and time in iso format,
#  e.g. "2021-12-29 23:43:24"
function now()
{
  return strftime("%Y-%m-%d %H:%M:%S")
}
