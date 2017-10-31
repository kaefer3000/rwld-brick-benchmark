#!/usr/bin/awk -f

# Extracts rules to turn off things.

BEGIN {
  print "@prefix http: <http://www.w3.org/2011/http#> ." ;
  print "@prefix http_m: <http://www.w3.org/2011/http-methods#> ." ;
  print "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .";
  print "@prefix saref: <https://w3id.org/saref#> .";
  print "@prefix prop: <http://localhost:8080/> .";
  FS="[# ]"
}

# The line-by-line processing:
{
  if (NR > 1) { # ignoring CSV header
    print ("{ [] http:mthd http_m:PUT; http:requestURI prop:" $2 " ; http:body { prop:" $2 " rdf:value saref:Off . } . }") ;
  }
}

