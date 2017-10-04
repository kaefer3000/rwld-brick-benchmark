#!/bin/bash

set -e

[ -d "rdf-molecules" ] && echo "folder rdf-molecules exists, overwriting..." >&2 && rm -rf "rdf-molecules" && mkdir "rdf-molecules"

$(cat IBM_B3-p* ; rapper -i turtle -o ntriples $1  `# converting to N-Triples`) \
  | sed -E 's/\<\S*IBM_B3#(\S*)>/\1>/g'            `# making the building URIs relative` \
  | tee \
    >( awk 'BEGIN {FS=" "} $(NF-1) ~ /^<[^hH]\S+>$/ { print >> "rdf-molecules/"substr($(NF-1),2,length($(NF-1))-2) }' ) `# emit triples where the object  is from the building` \
  |    awk 'BEGIN {FS=" "} $1      ~ /^<[^hH]\S+>$/ { print >> "rdf-molecules/"substr($1     ,2,length($1     )-2) }'   `# emit triples where the subject is from the building`


