# Clarity Framework – token usage from a Codex JSONL event stream.
#
# Prints one line: input cached_input cache_write_input output reasoning_output
# Prints nothing when the stream carries no usage at all.
#
# Two event shapes are understood:
#   1. `turn.completed` with a per-turn `usage` object. These are summed.
#   2. A cumulative `total_token_usage` object (token-count events). Only the last one counts.
# Shape 2 is the fallback: a dispatch that dies on its rollout budget never emits `turn.completed`,
# which is exactly the run whose consumption is most worth knowing.

function num(s, key,   p, r) {
  p = index(s, "\"" key "\"")
  if (!p) return ""
  r = substr(s, p + length(key) + 2)
  sub(/^[[:space:]]*:[[:space:]]*/, "", r)
  if (r !~ /^[0-9]/) return ""
  sub(/[^0-9].*$/, "", r)
  return r
}

/"type":[[:space:]]*"turn\.completed"/ {
  v = num($0, "input_tokens")
  if (v == "") next
  found = 1
  i += v
  c += num($0, "cached_input_tokens")
  w += num($0, "cache_write_input_tokens")
  o += num($0, "output_tokens")
  q += num($0, "reasoning_output_tokens")
  next
}

/"total_token_usage"/ {
  t = substr($0, index($0, "\"total_token_usage\""))
  v = num(t, "input_tokens")
  if (v == "") next
  tf = 1
  ti = v
  tc = num(t, "cached_input_tokens") + 0
  to = num(t, "output_tokens") + 0
  tq = num(t, "reasoning_output_tokens") + 0
}

END {
  if (found) printf "%d %d %d %d %d\n", i, c, w, o, q
  else if (tf) printf "%d %d 0 %d %d\n", ti, tc, to, tq
}
