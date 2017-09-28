# rwld-brick-benchmark
A benchmark for Read-Write Linked Data clients

## Coding convention
* For `.gitignore` to tell between source files and intermediary files
  * All intermediary RDF data be N-Triples (`.nt`)
  * All intermediary SPARQL query results be tab-separated (`.tsv`)

## Evaluation directions
* Variables vs. enumerated terms
 * Enumerate all switches, lights, etc. (building hundreds of rules instead of having variables)
* Networking
 * Include external Web API
   * Do something if the weather goes bad (another external Web API)
 * Do something time-based (another -but local- web API)
 * Building description not in one file, but as Linked Data
   * Caching for mitigation?
* Numerical Computation
 * Check if there is a luminance sensor and only switch on if value below threshold (numeric comparison)
* Reasoning
 * Turn off all lights in a wing (reasoning)
 * Implement reasoning from RUN_APPS.py (reasoning)
 * Have all Brick and building data reasoned in one file vs. reason all the time on the base files

## Misc
* If the a switch serves as manual override, it should have a neutral state
* Find out where they say Brick uses RDFS-plus
* The Turtle serialiser is the fastest of rdf-ext's serialisers
