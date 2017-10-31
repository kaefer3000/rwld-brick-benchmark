#!/usr/bin/awk -f

#
# Creates comfort values for all URIs supplied.
#

BEGIN {
  FS="#" ;
  OFS=" " ;
  if (base == "") { base="http://localhost:8080/" ; }
  print "@prefix brack: <http://rwld-brick-benchmark.github.io/vocab#> ." ;
  print "@base <" base "> ." ;
}

# The line-by-line processing:
{
  if (NR > 1) { # ignoring CSV header
    print ("<" $1 "#" $2 ">", "brack:comfortValue", "\"" rand() * 0.2 + 0.1 "\"", ".") ;
  }
}

