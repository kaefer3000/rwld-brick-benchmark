#!/usr/bin/awk -f

# Extracts N3 rules (about inverse properties) from Brick's application examples

BEGIN {
  FS = "" ;
#  print "@prefix bf: <https://brickschema.org/schema/1.0.1/BrickFrame#> .";
  print "@prefix bf: <http://buildsys.org/ontologies/BrickFrame#> ."
}

/RELATIONSHIPS$/      { inSection = 1 }; # the "rule" section starts
/Occupancy Modeling$/ { inSection = 0 }; # the "rule" section ends

(inSection) {
  # extracting rule body from SPARQL query:
  match($0, /({.*})/, arr); 
  if (RLENGTH > -1) {
    print arr[1], "=>";
  };
  # extracting rule head from python code:
  if ($0 ~ /g\.add/) {
    sub(/g\.add\(/, "");
    sub(/\)$/, "");
    sub(/\(/, "{");
    sub(/\)/, " .}");
    gsub(/,/, "");
    gsub(/row\[1\]/, "?b");
    gsub(/row\[0\]/, "?a");
    gsub(/BRICKFRAME\./, "bf:");
    print $0, ".";
  }
}
