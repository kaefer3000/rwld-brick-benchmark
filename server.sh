#!/bin/bash

SCRIPTDIR=$(dirname "$(readlink -f "$0")")
LDF_VERSION="0.9.12"
LDF_DIR="$SCRIPTDIR/linked-data-fu-$LDF_VERSION"

TMPDIR="$SCRIPTDIR/tmp"
MOLTMPDIR="$TMPDIR/rdf-molecules"

if [ ! -d "$TMPDIR" ] ; then
  echo "initialise first" >&2
  exit 1
fi

function startserver {

  case $1 in

    all)
      echo "starting both" >&2
      startserver property
      startserver building
      return
      ;;

    building)
      mvn -f "server/ldbbc/pom.xml" -D"jetty.port=8081" jetty:run &

      echo $! > "$TMPDIR"/server-building.pid

      sleep 10

      find $MOLTMPDIR/ -type f | xargs -l1 curl -X PUT localhost:8081/ldbbc/ -Hcontent-type:text/turtle -T

      ;;

    property)
      # special treatment for occupancy sensors, as they should (not) sense at random
      OCCSENS=$(tail -q -n+2                                        `# skip the CSV headers silently` \
          "$TMPDIR"/IBM_B3-occupancy-sensors.tsv \
        | awk -F'#' '{ print "-r", $2 }' | xargs echo)

      tail -q -n+2                                                  `# skip the CSV headers silently` \
          "$TMPDIR"/IBM_B3-lights.tsv \
          "$TMPDIR"/IBM_B3-occupancy-sensors.tsv \
          "$TMPDIR"/IBM_B3-luminance-commands.tsv \
        | awk -F'#' '{ print $2 }'                                  `# extract the fragment identifiers` \
        | (xargs node server/ld-ssn-properties/index.js $OCCSENS )& `# startup the server with the fragment identifiers`

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
      echo "stopping both" >&2
      stopserver property
      stopserver building
      return
      ;;

    building)
      KCMD="kill"
      ;;

    property)
      KCMD="pkill -P"
      ;;

    *)
      usage
      ;;
  esac

  if [ -f "$TMPDIR"/$1-server.pid ] ; then
    $KCMD $(cat "$TMPDIR"/$1-server.pid) && echo "Stopped $1 server" >&2 && rm "$TMPDIR"/server-$1.pid
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

