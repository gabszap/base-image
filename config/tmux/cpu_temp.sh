#!/usr/bin/env bash
sensors 2>/dev/null | awk '
BEGIN { n = 0 }
/^Core [0-9]+/ {
  if (match($3, /[+-]?[0-9.]+/)) {
    val = substr($3, RSTART, RLENGTH)
    sum += val
    n++
  }
}
END {
  if (n > 0) printf "%.0fC\n", sum / n
  else print "--"
}'