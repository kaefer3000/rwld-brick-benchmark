#!/bin/bash

set -e

SCRIPTDIR=$(dirname "$(readlink -f "$0")")
LDF_VERSION="0.9.12"
LDF_DIR="$SCRIPTDIR/linked-data-fu-$LDF_VERSION"

TMPDIR="$SCRIPTDIR/tmp"
MOLTMPDIR="$TMPDIR/rdf-molecules"

SPEEDUP="1000"

if [ ! -d "$TMPDIR" ] ; then
  echo "initialise first" >&2
  exit 1
fi

function startserver {

  case $1 in

    all)
      echo "starting all" >&2
      startserver property
      startserver building
      startserver time
      startserver weather
      return
      ;;

    time)
      if [ -f "$TMPDIR"/server-time.pid ] ; then
        echo "time server already running" >&2
        return
      fi
      MAVEN_OPTS=-Dorg.slf4j.simpleLogger.log.org.eclipse.jetty.server.RequestLog=warn mvn -f "server/timeservlet/pom.xml" -D"jetty.port=8082" -D"timeservlet.speedupfactor=$SPEEDUP" jetty:run &

      echo $! > "$TMPDIR"/server-time.pid

      return
      ;;

    weather)
      if [ -f "$TMPDIR"/server-weather.pid ] ; then
        echo "weather server already running" >&2
        return
      fi
      node server/ld-weather-dummy/index.js -p 8083 --speedup "$SPEEDUP" &

      echo $! > "$TMPDIR"/server-weather.pid

      return
      ;;

    building)
      if [ -f "$TMPDIR"/server-building.pid ] ; then
        echo "building server already running" >&2
        return
      fi

      MAVEN_OPTS=-Dorg.slf4j.simpleLogger.log.org.eclipse.jetty.server.RequestLog=warn mvn -f "server/ldbbc/pom.xml" -D"jetty.port=8081" jetty:run &

      echo $! > "$TMPDIR"/server-building.pid

      sleep 10

      for file in $(find $MOLTMPDIR/ -type f) ; do
        curl -f -X PUT localhost:8081/ldbbc/ -Hcontent-type:text/turtle -T $file
      done

      curl -f -X PUT localhost:8081/ldbbc/ -Hcontent-type:text/turtle -T $SCRIPTDIR/brick/GroundTruth/building_instances/IBM_B3.ttl

      for file in $(find $SCRIPTDIR/brick/GroundTruth/Brick/ -name 'B*ttl' -type f) ; do
        curl -f -X PUT localhost:8081/ldbbc/ -Hcontent-type:text/turtle -T $file
      done

      for file in $(find $TMPDIR -type f -name 'IBM_B3-p*ttl') ; do
        curl -f -X PUT localhost:8081/ldbbc/ -Hcontent-type:text/turtle -T $file
      done

      ;;

    property)
      if [ -f "$TMPDIR"/server-property.pid ] ; then
        echo "property server already running" >&2
        return
      fi

      # special treatment for occupancy sensors, as they should (not) sense at random
      OCCSENS=$(tail -q -n+2                                        `# skip the CSV headers silently` \
          "$TMPDIR"/IBM_B3-occupancy-sensors.tsv \
        | awk -F'#' '{ print "-o", $2 }' | xargs echo)
      LUMSENS=$(tail -q -n+2                                        `# skip the CSV headers silently` \
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

      node server/ld-ssn-properties/index.js $OCCSENS $LUMSENS $SWITCHES $LIGHTS $ALARMS --speedup "$SPEEDUP" & `# startup the server with the fragment identifiers`

      echo $! > "$TMPDIR"/server-property.pid
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
      stopserver property
      stopserver building
      stopserver weather
      stopserver time
      return
      ;;

    building|time|weather|property)
      KCMD="kill"
      ;;

    notUseFulAnyLonger)
      KCMD="pkill -P"
      ;;

    *)
      usage
      ;;
  esac

  if [ -f "$TMPDIR"/server-$1.pid ] ; then
    $KCMD $(cat "$TMPDIR"/server-$1.pid) && echo "Stopped $1 server" >&2 && rm "$TMPDIR"/server-$1.pid
  else
    echo "No $1 server to stop" >&2
  fi
}

function usage {
  echo "usage: $0 <start|stop> <building|property|all>" >&2
  exit 1
}

case $1 in
  start)
    startserver $2
    ;;

  stop)
    stopserver $2
    ;;

  *)
    usage
    ;;
esac

