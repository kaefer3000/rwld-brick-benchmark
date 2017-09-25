#!/usr/bin/awk

#
# Creates ssn:hasProperty links for all local names of hash URIs supplied.
# The base URI for the ends of the links can be overriden on cli using -v base=<URI>
#

BEGIN {
  FS="#" ;
  OFS=" " ;
  if (base == "") { base="http://localhost:8080/" ; }
  print "@prefix ssn: <http://www.w3.org/ns/ssn/> ." ;
  print "@base <" base "> ." ;
}

# The line-by-line processing:
{
  if ( NR > 1) { # ignoring CSV header
    print ("<" $1 "#" $2 ">", "ssn:hasProperty", "<" $2 "#it>", ".") ;
  }
}

