#!/bin/bash

# fail the script if a command fails
set -e

OPTIND=1 # reset getopts

SCRIPTDIR=$(dirname "$(readlink -f "$0")")
LDF_VERSION="0.9.12"
LDF_DIR="$SCRIPTDIR/linked-data-fu-$LDF_VERSION"

TMPDIR="$SCRIPTDIR/tmp"
MOLTMPDIR="$TMPDIR/rdf-molecules"

BUILDINGCOUNT=1
HOSTNAME="localhost"

while getopts "?n:h:" opt; do
  case "$opt" in
    n)
      BUILDINGCOUNT="$OPTARG"
    ;;
    h)
      HOSTNAME="$OPTARG"
    ;;
    \?)
      echo "$0 [ -? -n <buildingcount> -h <hostname> ]" >&2
      exit
    ;;
  esac
done

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

# Extract all luminance alarms (indicating light failure)
$LDF_DIR/bin/ldfu.sh \
  -i "$TMPDIR"/IBM_B3_rdfsplus.ttl \
  -q queries/luminance-alarms.rq "$TMPDIR"/IBM_B3-luminance-alarms.tsv

# Extract all occupancy sensors
$LDF_DIR/bin/ldfu.sh \
  -i "$TMPDIR"/IBM_B3_rdfsplus.ttl \
  -q queries/occupancy-sensors.rq "$TMPDIR"/IBM_B3-occupancy-sensors.tsv

# Extract all luminance sensors
$LDF_DIR/bin/ldfu.sh \
  -i "$TMPDIR"/IBM_B3_rdfsplus.ttl \
  -q queries/luminance-sensors.rq "$TMPDIR"/IBM_B3-luminance-sensors.tsv

# Extract all lights that can be switched and have an occupancy sensor
$LDF_DIR/bin/ldfu.sh \
  -i "$TMPDIR"/IBM_B3_rdfsplus.ttl \
  -q queries/lights-with-command-and-sensor.rq "$TMPDIR"/IBM_B3-lights-with-command-and-sensor.tsv

##
## Creating ssn:hasProperty links
##

for ((cnt=0;cnt<$BUILDINGCOUNT;cnt++)); do

  if [ ! -d "$TMPDIR"/"$cnt" ] ; then
    mkdir "$TMPDIR"/"$cnt"
  fi

  awk -f "scripts/ssn-properties-for-things.awk" -v base="http://$HOSTNAME:$( expr 40300 + $cnt )/" "$TMPDIR"/IBM_B3-luminance-commands.tsv \
    | rapper -i turtle -o turtle -I"http://buildsys.org/ontologies/examples/IBM_B3#" - > "$TMPDIR"/"$cnt"/"IBM_B3-property-links-for-luminance-commands.ttl"
  awk -f "scripts/ssn-properties-for-things.awk" -v base="http://$HOSTNAME:$( expr 40300 + $cnt )/" "$TMPDIR"/IBM_B3-luminance-alarms.tsv \
    | rapper -i turtle -o turtle -I"http://buildsys.org/ontologies/examples/IBM_B3#" - > "$TMPDIR"/"$cnt"/"IBM_B3-property-links-for-luminance-alarms.ttl"
  awk -f "scripts/ssn-properties-for-things.awk" -v base="http://$HOSTNAME:$( expr 40300 + $cnt )/" "$TMPDIR"/IBM_B3-occupancy-sensors.tsv \
    | rapper -i turtle -o turtle -I"http://buildsys.org/ontologies/examples/IBM_B3#" - > "$TMPDIR"/"$cnt"/"IBM_B3-property-links-for-occupancy-sensors.ttl"
  awk -f "scripts/ssn-properties-for-things.awk" -v base="http://$HOSTNAME:$( expr 40300 + $cnt )/" "$TMPDIR"/IBM_B3-luminance-sensors.tsv \
    | rapper -i turtle -o turtle -I"http://buildsys.org/ontologies/examples/IBM_B3#" - > "$TMPDIR"/"$cnt"/"IBM_B3-property-links-for-luminance-sensors.ttl"
  awk -f "scripts/comfort-values-for-things.awk" -v base="http://$HOSTNAME:$( expr 40300 + $cnt )/" "$TMPDIR"/IBM_B3-luminance-sensors.tsv \
    | rapper -i turtle -o turtle -I"http://buildsys.org/ontologies/examples/IBM_B3#" - > "$TMPDIR"/"$cnt"/"IBM_B3-personal-comfort-values-for-luminance-sensors.ttl"
  awk -f "scripts/ssn-properties-for-things.awk" -v base="http://$HOSTNAME:$( expr 40300 + $cnt )/" "$TMPDIR"/IBM_B3-lights.tsv \
    | rapper -i turtle -o turtle -I"http://buildsys.org/ontologies/examples/IBM_B3#" - > "$TMPDIR"/"$cnt"/"IBM_B3-property-links-for-lights.ttl"

  for file in $(find "$TMPDIR"/"$cnt"/ -type f -name 'IBM_B3-property-links-for-*ttl') ; do
    NEWNAME=$(echo $file | sed 's/\.ttl$/.nt/')
    rapper -i turtle -o ntriples $file > $NEWNAME
  done

done

##
## Extraction of triples that belong to building things into rdf molecules
##

mkdir $MOLTMPDIR

for ((cnt=0;cnt<$BUILDINGCOUNT;cnt++)); do

  mkdir $MOLTMPDIR/$cnt

  cat "$TMPDIR"/$cnt/IBM_B3-p* brick/GroundTruth/building_instances/IBM_B3.ttl \
    | rapper -i turtle -o ntriples -I"http://ex.org" - `# converting to N-Triples` \
    | sed -E 's/\<\S*IBM_B3#(\S*)>/\1>/g'              `# making the building URIs relative` \
    | tee \
      >( awk -v directory="$MOLTMPDIR"/"$cnt" 'BEGIN {FS=" "} $(NF-1) ~ /^<[^hH]\S+>$/ { print >> directory"/"substr($(NF-1),2,length($(NF-1))-2) ; fflush() }' ) `# emit triples where the object  is from the building` \
    |    awk -v directory="$MOLTMPDIR"/"$cnt" 'BEGIN {FS=" "} $1      ~ /^<[^hH]\S+>$/ { print >> directory"/"substr($1     ,2,length($1     )-2) ; fflush() }'   `# emit triples where the subject is from the building`

done

##
## Extracting rules for inverse properties.
##

./scripts/extract-inverse-property-rules-from-brick-application-examples.awk brick/GroundTruth/application_examples/RUN_APPS.py > $TMPDIR/brick-inverse-properties.n3

##
## Extracting subsets of the rooms in the building
##

WINGQUERY=$SCRIPTDIR/queries/parts-of.Wing_SOR46.rq
cp $WINGQUERY $TMPDIR/$(basename $WINGQUERY)
for set in "Room_SOR42_G_19" "fiverooms" "tenrooms" "twentyrooms" "Floor_FirstFloor" "Building_B3" ; do
  NEWNAME=$(basename $(echo $WINGQUERY | sed "s/Wing_SOR46/$set/"))
  sed "s/Wing_SOR46/$set/" $WINGQUERY > $TMPDIR/$NEWNAME
done

for file in $(find $SCRIPTDIR/tmp/ -name 'parts-of.*.rq'); do
  set=$(echo $file | sed -E 's/.*parts-of\.(.*)\.rq/\1/')
  $SCRIPTDIR/linked-data-fu-0.9.12/bin/ldfu.sh -i "$TMPDIR"/IBM_B3_rdfsplus.ttl -i $SCRIPTDIR/brick/n-rooms.ttl -q $file "$TMPDIR"/IBM_B3-parts-of.$set.tsv

  touch "$TMPDIR"/turn-lightswitches-off.$set.get.n3
  awk -f $SCRIPTDIR/scripts/extract-turn-off-lights-rules.awk "$TMPDIR"/IBM_B3-parts-of.$set.tsv > "$TMPDIR"/turn-lightswitches-off.$set.put.n3

  touch "$TMPDIR"/toggle-lightswitches.$set.get.n3
  touch "$TMPDIR"/toggle-lightswitches.$set.put.n3
done

##
## Preparing servers
##

# Installing server dependencies
npm --prefix "server/ld-ssn-properties" install
mvn -f "server/ldbbc/pom.xml" -D"jetty.skip=true" jetty:run
mvn -f "server/timeservlet/pom.xml" -D"jetty.skip=true" jetty:run
mvn -f "server/coinflip-servlet/pom.xml" -D"jetty.skip=true" jetty:run

