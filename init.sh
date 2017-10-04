#!/bin/bash

# fail the script if a command fails
set -e

SCRIPTDIR=$(dirname "$(readlink -f "$0")")
LDF_VERSION="0.9.12"
LDF_DIR="$SCRIPTDIR/linked-data-fu-$LDF_VERSION"

TMPDIR="$SCRIPTDIR/tmp"
MOLTMPDIR="$TMPDIR/rdf-molecules"

[ -d "$TMPDIR" ] && echo "temp folder $TMPDIR exists, overwriting..." >&2 && rm -rf "$TMPDIR" 

mkdir "$TMPDIR"

cd $SCRIPTDIR

# Checking for Linked Data-Fu
if [ ! -d $LDF_DIR ] ; then
  >&2 echo "Linked Data-Fu not found, obtaining..."

  if [ ! -d "linked-data-fu-standalone-$LDF_VERSION-bin.tar.gz" ] ; then
    wget "https://linked-data-fu.github.io/releases/$LDF_VERSION/linked-data-fu-standalone-$LDF_VERSION-bin.tar.gz"
  fi

  tar xzf "linked-data-fu-standalone-$LDF_VERSION-bin.tar.gz"
  rm "linked-data-fu-standalone-$LDF_VERSION-bin.tar.gz"
fi

# Reasoning on the IBM B3 building description
$LDF_DIR/bin/ldfu.sh \
  -p $LDF_DIR/rulesets/rdfs-plus.n3                  `# reasoning rules, expressivity see Brick paper?` \
  -i brick/GroundTruth/Brick/*ttl                    `# version 1.0.0 of the Brick ontology` \
  -i brick/GroundTruth/building_instances/IBM_B3.ttl `# IBM B3 building instance that uses version 1.0.0 of the ontology` \
  -o - \
  | rapper -i nquads -o turtle -I "http://ex.org" -  `# pretty printing (with required base URI)` \
  | grep -v '^@base'                                 `# removing the (here unnecessary) base URI` \
  > "$TMPDIR"/IBM_B3_rdfsplus.ttl 

##
## Extraction of lights, light switches, and occupancy sensors
##

# Extract all lights
$LDF_DIR/bin/ldfu.sh \
  -i "$TMPDIR"/IBM_B3_rdfsplus.ttl \
  -q queries/lights.rq "$TMPDIR"/IBM_B3-lights.tsv

# Extract all luminance commands, ie switches?
$LDF_DIR/bin/ldfu.sh \
  -i "$TMPDIR"/IBM_B3_rdfsplus.ttl \
  -q queries/luminance-commands.rq "$TMPDIR"/IBM_B3-luminance-commands.tsv

# Extract all occupancy sensors
$LDF_DIR/bin/ldfu.sh \
  -i "$TMPDIR"/IBM_B3_rdfsplus.ttl \
  -q queries/occupancy-sensors.rq "$TMPDIR"/IBM_B3-occupancy-sensors.tsv

# Extract all lights that can be switched and have an occupancy sensor
$LDF_DIR/bin/ldfu.sh \
  -i "$TMPDIR"/IBM_B3_rdfsplus.ttl \
  -q queries/lights-with-command-and-sensor.rq "$TMPDIR"/IBM_B3-lights-with-command-and-sensor.tsv

##
## Creating ssn:hasProperty links
##

awk -f "scripts/ssn-properties-for-things.awk" "$TMPDIR"/IBM_B3-luminance-commands.tsv \
  | rapper -i turtle -o turtle -I"http://buildsys.org/ontologies/examples/IBM_B3#" - > "$TMPDIR"/"IBM_B3-property-links-for-luminance-commands.ttl"
awk -f "scripts/ssn-properties-for-things.awk" "$TMPDIR"/IBM_B3-occupancy-sensors.tsv \
  | rapper -i turtle -o turtle -I"http://buildsys.org/ontologies/examples/IBM_B3#" - > "$TMPDIR"/"IBM_B3-property-links-for-occupancy-sensors.ttl"
awk -f "scripts/ssn-properties-for-things.awk" "$TMPDIR"/IBM_B3-lights.tsv \
  | rapper -i turtle -o turtle -I"http://buildsys.org/ontologies/examples/IBM_B3#" - > "$TMPDIR"/"IBM_B3-property-links-for-lights.ttl"

##
## Extraction of triples that belong to building things into rdf molecules
##

mkdir $MOLTMPDIR

cat "$TMPDIR"/IBM_B3-p* brick/GroundTruth/building_instances/IBM_B3.ttl \
  | rapper -i turtle -o ntriples -I"http://ex.org" - `# converting to N-Triples` \
  | sed -E 's/\<\S*IBM_B3#(\S*)>/\1>/g'              `# making the building URIs relative` \
  | tee \
    >( awk -v directory="$MOLTMPDIR" 'BEGIN {FS=" "} $(NF-1) ~ /^<[^hH]\S+>$/ { print >> directory"/"substr($(NF-1),2,length($(NF-1))-2) ; fflush() }' ) `# emit triples where the object  is from the building` \
  |    awk -v directory="$MOLTMPDIR" 'BEGIN {FS=" "} $1      ~ /^<[^hH]\S+>$/ { print >> directory"/"substr($1     ,2,length($1     )-2) ; fflush() }'   `# emit triples where the subject is from the building`

##
## Preparing servers
##

# Installing server dependencies
npm --prefix "server/ld-ssn-properties" install
mvn -f "server/ldbbc/pom.xml" -D"jetty.skip=true" jetty:run

