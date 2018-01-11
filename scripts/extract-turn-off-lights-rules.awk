#!/usr/bin/awk -f

# Extracts rules to turn off things.
# The base URI for the URIs on the property server can be overriden on cli using -v base=<URI>

BEGIN {
  if (base == "") { base="http://localhost:40300/" ; }
  print "@prefix http: <http://www.w3.org/2011/http#> ." ;
  print "@prefix http_m: <http://www.w3.org/2011/http-methods#> ." ;
  print "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .";
  print "@prefix saref: <https://w3id.org/saref#> .";
  print "@prefix prop: <" base "> .";
  FS="[# ]"
}

# The line-by-line processing:
{
  if (NR > 1) { # ignoring CSV header
    print ("{ [] http:mthd http_m:PUT; http:requestURI prop:" $2 " ; http:body { prop:" $2 " rdf:value saref:Off . } . }") ;
  }
}

