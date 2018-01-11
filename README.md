# rwld-brick-benchmark
A benchmark for Read-Write Linked Data clients

## Prerequisites
* Java >= 7
* Maven >= Version 3.1
* WGET
* CURL
* AWK
* node.js

## Obtain
You have to tell git to also fetch the submodules
`git clone https://github.com/kaefer3000/rwld-brick-benchmark --recursive`

## Usage for rule-based automation benchmark
* `./init.sh` To initialise data
* `./server.sh start all` To start all servers (requires free ports between `40100` and `40399`)
* `./benchmark.sh` To run the benchmarking script

### Evaluation directions
* Data access:
  * All data in one file on an HTTP server
  * Deployed as Linked Data: RDF molecules from the materialised reasoning of Brick ontology + IBM B3 building description
* Work loads:
  * Turn on the lights - baseline - baseline
  * Turn on the lights during working hours (eg. 7 am to 7 pm) - raising energy efficiency - adding conditions
  * Turn on the lights if weather report says it is dark - raising energy efficiency - adding conditions and external API
  * Turn on the lights if light sensors indicate - raising energy efficiency even more - many numerical computations
  * Turn on the lights if light sensors indicate (with individial thresholds) - adding individual preference for comfort - more numerical computations
  
  * Toggle the lights - adding conditions

## Usage for workflow-based automation benchmark
* `./init.sh -n <buildingcount> -h <hostname>` To initialise data
* `./server.sh -n <buildingcount> -s <speedupfactor> start all` To start all servers
Supply the number of buildings to be simulated, default: `1`.
If the client does not run on localhost, supply the hostname, default: `localhost`.
The speedup factor sets the factor between wall clock time and simulated time, default: `613200`.

## Misc
* If the a switch serves as manual override, it should have a neutral state
* Find out where they say Brick uses RDFS-plus
* The Turtle serialiser is the fastest of rdf-ext's serialisers
