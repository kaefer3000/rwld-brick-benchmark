#!/usr/bin/awk -f

#
# Creates ssn:observes links for all local names of hash URIs supplied.
# The base URI for the ends of the links can be overriden on cli using -v base=<URI>
#

BEGIN {
  FS="#" ;
  OFS=" " ;
  if (base == "") { base="http://localhost:40300/" ; }
  print "@prefix sosa: <http://www.w3.org/ns/sosa/> ." ;
  print "@base <" base "> ." ;
}

# The line-by-line processing:
{
  if (NR > 1) { # ignoring CSV header
    print ("<" $1 "#" $2 ">", "sosa:observes", "<" $2 "#it>", ".") ;
  }
}

