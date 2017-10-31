#!/bin/bash

set -e

ITERATIONS=20
SAFETYFACTOR=2

echo "=================================BRACK========================================="
echo "======= Benchmarking Read-write user Agents and Clients for linKed data  ======"
echo "=================================BRACK========================================="

if [ $(curl -qf http://localhost:8081/ldbbc/ 2> /dev/null > /dev/null ; echo $?) -ne "0" ] || [ $(curl -qf http://localhost:8080/ 2> /dev/null > /dev/null ; echo $?) -ne "0" ] ; then
  echo "Please start the servers first, ie. run \"./server.sh start all\" to start all"
  exit 1
fi

echo "Benchmarking with $ITERATIONS iterations..."

rm -f ldf.out

function tlo {

# Resetting the property server
curl -qf -X DELETE http://localhost:8080/ 2> /dev/null > /dev/null

for file in $(find rules/behaviour/ -name $2".wing.*n3"); do
  NEWNAME=$(echo $file | sed 's/wing/x/')
  cp $file $NEWNAME
  sed -i "s/Wing_SOR46/$1/g" $NEWNAME
done

#echo -ne "Reading the entire building from disk. Median time [ms]:\t\t"
#(timeout $((400 * $SAFETYFACTOR * $ITERATIONS / 1000)) \
#./linked-data-fu-0.9.12/bin/ldfu.sh -p rules/reasoning/hasPartIsTransitive.n3 -p tmp/brick-inverse-properties.n3 \
#-i brick/GroundTruth/building_instances/IBM_B3.ttl -i tmp/IBM_B3-property-links-f*ttl \
#-p rules/behaviour/$2/$2.x.get.rdf.n3 -p rules/behaviour/$2/$2.x.put.rdf.n3 \
#-n 2>&1 ) | tee -a ldf.out | grep lapsed | head -$ITERATIONS | awk '{sub(/\./,"",$4); print $4}' | sort | ./scripts/median.awk

#echo -ne "Reading the entire building from disk (caching). Median time [ms]:\t"
#(timeout $((500 * $SAFETYFACTOR * $ITERATIONS / 1000)) \
#./linked-data-fu-0.9.12/bin/ldfu.sh -p rules/reasoning/hasPartIsTransitive.n3 -p tmp/brick-inverse-properties.n3 \
#-p brick/GroundTruth/building_instances/IBM_B3.ttl -p tmp/IBM_B3-property-links-f*nt  \
#-p rules/behaviour/$2/$2.x.get.rdf.n3 -p rules/behaviour/$2/$2.x.put.rdf.n3 \
#-n 2>&1 ) | tee -a ldf.out | grep lapsed | head -$ITERATIONS | awk '{sub(/\./,"",$4); print $4}' | sort | ./scripts/median.awk

echo -ne "Reading the entire building from network. Median time [ms]:\t\t"
(timeout $((500 * $SAFETYFACTOR * $ITERATIONS / 1000)) \
./linked-data-fu-0.9.12/bin/ldfu.sh -p rules/reasoning/hasPartIsTransitive.n3 -p tmp/brick-inverse-properties.n3 \
-i "http://localhost:8081/ldbbc/IBM_B3.ttl" -i "http://localhost:8081/ldbbc/IBM_B3-property-links-for-lights.ttl" -i "http://localhost:8081/ldbbc/IBM_B3-property-links-for-occupancy-sensors.ttl" -i "http://localhost:8081/ldbbc/IBM_B3-property-links-for-luminance-commands.ttl" -i "http://localhost:8081/ldbbc/IBM_B3-property-links-for-luminance-sensors.ttl" -i "http://localhost:8081/ldbbc/IBM_B3-property-links-for-luminance-alarms.ttl" -i "http://localhost:8081/ldbbc/IBM_B3-personal-comfort-values-for-luminance-sensors.ttl" \
-p rules/behaviour/$2/$2.x.get.rdf.n3 -p rules/behaviour/$2/$2.x.put.rdf.n3 \
-n 2>&1 ) | tee -a ldf.out | grep lapsed | head -$ITERATIONS | awk '{sub(/\./,"",$4); print $4}' | sort | ./scripts/median.awk

# Resetting the property server
curl -qf -X DELETE http://localhost:8080/ 2> /dev/null > /dev/null

echo -ne "Reading the relevant Linked Data from the network. Median time [ms]:\t"
(timeout $((1300 * $SAFETYFACTOR * $ITERATIONS / 1000)) \
./linked-data-fu-0.9.12/bin/ldfu.sh -p rules/reasoning/hasPartIsTransitive.n3 -p tmp/brick-inverse-properties.n3 \
-p rules/behaviour/$2/$2.x.get.ld.n3 -p rules/behaviour/$2/$2.x.put.ld.n3 \
-n 2>&1 ) | tee -a ldf.out | grep lapsed | head -$ITERATIONS | awk '{sub(/\./,"",$4); print $4}' | sort | ./scripts/median.awk

#echo -ne "Rules without variables. Median time [ms]:\t"
#(timeout $((600 * $SAFETYFACTOR * $ITERATIONS / 1000)) \
#./linked-data-fu-0.9.12/bin/ldfu.sh -p tmp/$2.$1.get.n3 -p tmp/$2.$1.put.n3 \
#-n 2>&1 ) | tee -a ldf.out | grep lapsed | head -$ITERATIONS | awk '{sub(/\./,"",$4); print $4}' | sort | ./scripts/median.awk

}

for behaviour in "individual-light-sensor-based-control" "clock-based-control" "sun-hour-based-control" "light-sensor-based-control" "turn-lightswitches-on" ; do
  echo
  echo "============== behaviour: $behaviour =============="
  for place in Room_SOR42_G_19 fiverooms tenrooms twentyrooms Floor_FirstFloor Wing_SOR46 Building_B3 ; do
    echo
    echo "== $behaviour in $place..."
    tlo $place $behaviour
  done
  find rules/behaviour/ -name "$behaviour.x.*n3" -delete
done

