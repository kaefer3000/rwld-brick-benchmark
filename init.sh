#!/bin/sh

# fail the script if a command fails
set -e

SCRIPTDIR=$(dirname "$(readlink -f "$0")")
LDF_VERSION="0.9.12"
LDF_DIR="$SCRIPTDIR/linked-data-fu-$LDF_VERSION"

cd $SCRIPTDIR

# Checking for Linked Data-Fu
if [ ! -d $LDF_DIR ] ; then
  >&2 echo "Linked Data-Fu not found, obtaining..."

  if [ ! -d "linked-data-fu-standalone-$LDF_VERSION-bin.tar.gz" ] ; then
    wget "https://linked-data-fu.github.io/releases/$LDF_VERSION/linked-data-fu-standalone-$LDF_VERSION-bin.tar.gz" || exit 1
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
  | rapper -i nquads -o ntriples -I"http://ex.org" - > brick/IBM_B3_rdfsplus.nt # pretty printing

##
## Extraction of lights, light switches, and occupancy sensors
##

# Extract all lights
$LDF_DIR/bin/ldfu.sh \
  -i brick/IBM_B3_rdfsplus.nt \
  -q queries-and-results/lights.rq queries-and-results/IBM_B3-lights.tsv

# Extract all luminance commands, ie switches?
$LDF_DIR/bin/ldfu.sh \
  -i brick/IBM_B3_rdfsplus.nt \
  -q queries-and-results/luminance-commands.rq queries-and-results/IBM_B3-luminance-commands.tsv

# Extract all occupancy sensors
$LDF_DIR/bin/ldfu.sh \
  -i brick/IBM_B3_rdfsplus.nt \
  -q queries-and-results/occupancy-sensors.rq queries-and-results/IBM_B3-occupancy-sensors.tsv

# Extract all lights that can be switched and have an occupancy sensor
$LDF_DIR/bin/ldfu.sh \
  -i brick/IBM_B3_rdfsplus.nt \
  -q queries-and-results/lights-with-command-and-sensor.rq queries-and-results/IBM_B3-lights-with-command-and-sensor.tsv

##
## Creating ssn:hasProperty links
##

awk -f "scripts/ssn-properties-for-things.awk" queries-and-results/IBM_B3-luminance-commands.tsv \
  | rapper -i turtle -o ntriples -I"http://ex.org" - > "IBM_B3-property-links-for-luminance-commands.nt"
awk -f "scripts/ssn-properties-for-things.awk" queries-and-results/IBM_B3-occupancy-sensors.tsv \
  | rapper -i turtle -o ntriples -I"http://ex.org" - > "IBM_B3-property-links-for-occupancy-sensors.nt"
awk -f "scripts/ssn-properties-for-things.awk" queries-and-results/IBM_B3-lights.tsv \
  | rapper -i turtle -o ntriples -I"http://ex.org" - > "IBM_B3-property-links-for-lights.nt"

##
##  Starting up the server for all lights, sensors, and switches
##

# installing server dependencies
npm --prefix server install

tail -q -n+2                   `# skip the CSV headers silently` \
    queries-and-results/IBM_B3-lights.tsv queries-and-results/IBM_B3-occupancy-sensors.tsv queries-and-results/IBM_B3-luminance-commands.tsv \
  | awk -F'#' '{ print $2 }'     `# extract the fragment identifiers` \
  | xargs node server/index.js `# startup the server with the fragment identifiers`

