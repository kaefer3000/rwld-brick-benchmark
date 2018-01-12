#!/bin/bash

set -e

OPTIND=1 # reset getopts

SCRIPTDIR=$(dirname "$(readlink -f "$0")")
LDF_VERSION="0.9.12"
LDF_DIR="$SCRIPTDIR/linked-data-fu-$LDF_VERSION"

TMPDIR="$SCRIPTDIR/tmp"
MOLTMPDIR="$TMPDIR/rdf-molecules"

SPEEDUP="613200"

BUILDINGCOUNT="1"

if [ ! -d "$TMPDIR" ] ; then
  echo "initialise first" >&2
  exit 1
fi

function startserver {

  case $1 in

    all)
      echo "starting all" >&2
      startserver building
      startserver property
      startserver time
      startserver coin
      startserver weather
      return
      ;;

    time)
      if [ -f "$TMPDIR"/server-time.pid ] ; then
        echo "time server already running" >&2
        return
      fi
      MAVEN_OPTS=-Dorg.slf4j.simpleLogger.log.org.eclipse.jetty.server.RequestLog=warn mvn -f "server/timeservlet/pom.xml" -D"jetty.port=40102" -D"timeservlet.speedupfactor=$SPEEDUP" jetty:run &

      echo $! > "$TMPDIR"/server-time.pid

      return
      ;;

    coin)
      if [ -f "$TMPDIR"/server-coin.pid ] ; then
        echo "coin server already running" >&2
        return
      fi
      MAVEN_OPTS=-Dorg.slf4j.simpleLogger.log.org.eclipse.jetty.server.RequestLog=warn mvn -f "server/coinflip-servlet/pom.xml" -D"jetty.port=40104" jetty:run &

      echo $! > "$TMPDIR"/server-coin.pid

      return
      ;;

    weather)
      if [ -f "$TMPDIR"/server-weather.pid ] ; then
        echo "weather server already running" >&2
        return
      fi
      node server/ld-weather-dummy/index.js -p 40103 --speedup "$SPEEDUP" &

      echo $! > "$TMPDIR"/server-weather.pid

      return
      ;;

    building)

      for ((cnt=0;cnt<$BUILDINGCOUNT;cnt++)); do

        if [ ! -d $MOLTMPDIR/$cnt ] ; then
          echo "no building data for building $cnt. Exiting." >&2
          exit 1
        fi

        if [ -f "$TMPDIR"/server-building-"$cnt".pid ] ; then
          echo "building server $cnt already running" >&2
          return
        fi

        MAVEN_OPTS=-Dorg.slf4j.simpleLogger.log.org.eclipse.jetty.server.RequestLog=warn mvn -f "server/ldbbc/pom.xml" -D"jetty.port=$( expr 40200 + $cnt )" jetty:run &

        echo $! > "$TMPDIR"/server-building-"$cnt".pid

        sleep 10

        for file in $(find $MOLTMPDIR/$cnt -type f) ; do
          curl -f -X PUT localhost:$( expr 40200 + $cnt )/ldbbc/ -Hcontent-type:text/turtle -T $file
        done

        curl -f -X PUT localhost:$( expr 40200 + $cnt )/ldbbc/ -Hcontent-type:text/turtle -T $SCRIPTDIR/brick/GroundTruth/building_instances/IBM_B3.ttl

        for file in $(find $SCRIPTDIR/brick/GroundTruth/Brick/ -name 'B*ttl' -type f) ; do
          curl -f -X PUT localhost:$( expr 40200 + $cnt )/ldbbc/ -Hcontent-type:text/turtle -T $file
        done

        for file in $(find $TMPDIR/$cnt -type f -name 'IBM_B3-p*ttl') ; do
          curl -f -X PUT localhost:$( expr 40200 + $cnt )/ldbbc/ -Hcontent-type:text/turtle -T $file
        done

      done

      ;;

    property)

      for ((cnt=0;cnt<$BUILDINGCOUNT;cnt++)); do
 
        if [ -f "$TMPDIR"/server-property-"$cnt".pid ] ; then
          echo "property server $cnt already running" >&2
          return
        fi

        # special treatment for occupancy sensors, as they should (not) sense at random
        OCCSENS=$(tail -q -n+2                                         `# skip the CSV headers silently` \
            "$TMPDIR"/IBM_B3-occupancy-sensors.tsv \
          | awk -F'#' '{ print "-o", $2 }' | xargs echo)
        LUMSENS=$(tail -q -n+2                                         `# skip the CSV headers silently` \
            "$TMPDIR"/IBM_B3-luminance-sensors.tsv \
          | awk -F'#' '{ print "-l", $2 }' | xargs echo)
        SWITCHES=$(tail -q -n+2                                        `# skip the CSV headers silently` \
            "$TMPDIR"/IBM_B3-luminance-commands.tsv \
          | awk -F'#' '{ print "-s", $2 }' | xargs echo)
        ALARMS=$(tail -q -n+2                                          `# skip the CSV headers silently` \
            "$TMPDIR"/IBM_B3-luminance-alarms.tsv \
          | awk -F'#' '{ print "-s", $2 }' | xargs echo)
        LIGHTS=$(tail -q -n+2                                          `# skip the CSV headers silently` \
            "$TMPDIR"/IBM_B3-lights.tsv \
          | awk -F'#' '{ print "-b", $2 }' | xargs echo)

        node server/ld-ssn-properties/index.js $OCCSENS $LUMSENS $SWITCHES $LIGHTS $ALARMS -p $( expr 40300 + $cnt ) --speedup "$SPEEDUP" & `# startup the server with the fragment identifiers`

        echo $! > "$TMPDIR"/server-property-"$cnt".pid

      done
      ;;

    *)
      usage
      ;;
  esac
}

function stopserver {

  case $1 in

    all)
      echo "stopping all" >&2
      startserver building
      startserver property
      startserver time
      startserver coin
      startserver weather
      return
      ;;

    building|time|weather|property|coin)
      KCMD="kill"
      ;;

    notUseFulAnyLonger)
      KCMD="pkill -P"
      ;;

    *)
      usage
      ;;
  esac

  shopt -s nullglob
  for file in "$TMPDIR"/server-$1*.pid ; do
    $KCMD $(cat $file) && echo "Stopped $1 server" >&2 || echo "Error stopping $1 server"
    rm $file
  done
}

function usage {
  echo "usage: $0 [-? -s <speedupfactor> -n <buildingcount>] <start|stop> <building|property|all>" >&2
  exit 1
}

while getopts "?s:n:" opt; do
  case "$opt" in
    s)
      SPEEDUP="$OPTARG"
    ;;
    n)
      BUILDINGCOUNT="$OPTARG"
    ;;
    \?)
      usage
    ;;
  esac
done

shift $((OPTIND-1))

case $1 in
  start)
    echo "Number of buildings: $BUILDINGCOUNT" >&2
    echo "Speedup factor: $SPEEDUP" >&2
    startserver $2
    ;;

  stop)
    stopserver $2
    ;;

  *)
    usage
    ;;
esac

