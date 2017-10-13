//
// Serves writeable ssn:Properties on a REST interface
//
// Author: kaefer3000
//

// Load the web framework
var express = require('express');
// Load the logger for the web framework
var logger = require('morgan');
// Load some parsers for HTTP message bodys
var bodyParser = require('body-parser');
// Load RDF
var rdf = require('rdf-ext')
// Load the RDF parsers for HTTP messages
var rdfBodyParser = require('rdf-body-parser');
var RdfXmlSerializer = require('rdf-serializer-rdfxml');
// Load CLI parser
var minimist = require('minimist');
// The root app
var app = express();

// Preparing to use my rdf/xml serialiser
var formatparams = {};
formatparams.serializers = new rdf.Serializers();
formatparams.serializers['application/rdf+xml'] = RdfXmlSerializer;
var formats = require('rdf-formats-common')(formatparams);

var configuredBodyParser = rdfBodyParser({'defaultMediaType' : 'text/turtle', 'formats' : formats});

var argv = minimist(process.argv.slice(2));

var cliToResourceType = { "o" : "dynamic" , "l" : "dynamic" , "s" : "ternary" , "b" : "binary", "f" : "binary" };

var typesOfResources = {};
var statesOfResources = {};
var dictArgv = {};

// Reading CLI
function setResourceStateAndType(typesOfResources, statesOfResources, dictArgv, cliArgument, resourceName, resourceType) {
  typesOfResources[resourceName] = resourceType;
  if (! (cliArgument in dictArgv)) 
    dictArgv[cliArgument] = {};

  dictArgv[cliArgument][resourceName] = true;
  if (resourceType === "ternary")
    statesOfResources[resourceName] = "neutral";
  else if (cliToResourceType[cliArgument] === "binary")
    statesOfResources[resourceName] = "off";
}
function readCli() {
  for (var cliArgument in cliToResourceType) {
    if (typeof argv[cliArgument] === "object")
      for (var key in argv[cliArgument])
        setResourceStateAndType(typesOfResources, statesOfResources, dictArgv, cliArgument, argv[cliArgument][key], cliToResourceType[cliArgument]);
    else if (typeof argv[cliArgument] === "string")
        setResourceStateAndType(typesOfResources, statesOfResources, dictArgv, cliArgument, argv[cliArgument], cliToResourceType[cliArgument]);
  }
}
readCli();

// configuring the app
app.set('case sensitive routing', true);
app.set('strict routing', true);
//app.use(logger('dev'));
app.use(configuredBodyParser);

// On root, we serve an overview
var rootGraph = rdf.createGraph();
for (resource in typesOfResources) {
  rootGraph.add(
    new rdf.Triple(
      new rdf.NamedNode(''),
      new rdf.NamedNode('http://www.w3.org/2000/01/rdf-schema#seeAlso'),
      new rdf.NamedNode(resource)
    )
  );
}
app.get('/', function(request, response) {
  response.sendGraph(rootGraph);
});
app.delete('/', function(request, response) {
  // To reset the server
  readCli();
  response.sendStatus(204);
});

// basic graph for all resources but root
var propertyBaseGraph = rdf.createGraph();
propertyBaseGraph.addAll(
  [
    new rdf.Triple(
      new rdf.NamedNode('#it'),
      new rdf.NamedNode('http://xmlns.com/foaf/0.1/isPrimaryTopicOf'),
      new rdf.NamedNode('')),
    new rdf.Triple(
      new rdf.NamedNode('#it'),
      new rdf.NamedNode('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
      new rdf.NamedNode('http://www.w3.org/ns/ssn/Property')),
    new rdf.Triple(
      new rdf.NamedNode('#it'),
      new rdf.NamedNode('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
      new rdf.NamedNode('http://www.w3.org/ns/sosa/ObservableProperty'))
  ])
var onTriple = new rdf.Triple(
                      new rdf.NamedNode('#it'),
                      new rdf.NamedNode('http://www.w3.org/1999/02/22-rdf-syntax-ns#value'),
                      new rdf.NamedNode('https://w3id.org/saref#On'));
var offTriple = new rdf.Triple(
                      new rdf.NamedNode('#it'),
                      new rdf.NamedNode('http://www.w3.org/1999/02/22-rdf-syntax-ns#value'),
                      new rdf.NamedNode('https://w3id.org/saref#Off'));
var neutralTriple = new rdf.Triple(
                      new rdf.NamedNode('#it'),
                      new rdf.NamedNode('http://www.w3.org/1999/02/22-rdf-syntax-ns#value'),
                      new rdf.NamedNode('http://example.org/Neutral'));
var rdfvalue = new rdf.NamedNode('http://www.w3.org/1999/02/22-rdf-syntax-ns#value');
var localIt = new rdf.NamedNode('#it');
var xsddouble = new rdf.NamedNode('http://www.w3.org/2001/XMLSchema#double');
var qudtNumericValue = new rdf.NamedNode('http://qudt.org/schema/qudt#numericValue');

var propertyBaseGraphOn = propertyBaseGraph.merge([onTriple]);
var propertyBaseGraphOff = propertyBaseGraph.merge([offTriple]);
var actuablePropertyBaseGraphOn = propertyBaseGraphOn.merge([
  new rdf.Triple(
    new rdf.NamedNode('#it'),
    new rdf.NamedNode('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
    new rdf.NamedNode('http://www.w3.org/ns/sosa/ActuableProperty'))
  ]);
var actuablePropertyBaseGraphOff = propertyBaseGraphOff.merge([
  new rdf.Triple(
    new rdf.NamedNode('#it'),
    new rdf.NamedNode('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
    new rdf.NamedNode('http://www.w3.org/ns/sosa/ActuableProperty'))
  ]);
var actuablePropertyBaseGraphNeutral = propertyBaseGraph.merge([
  neutralTriple,
  new rdf.Triple(
    new rdf.NamedNode('#it'),
    new rdf.NamedNode('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
    new rdf.NamedNode('http://www.w3.org/ns/sosa/ActuableProperty'))
  ]);

app.route("/:id").get(function(request, response) {

  var id = request.params.id;
  if (! (id in typesOfResources)) {
    response.sendStatus(404);
    return;
  }

  var state;
  switch (typesOfResources[id]) {
    case "dynamic":
      if ("o" in dictArgv && id in dictArgv["o"])
        // occupancy sensor:
        // periodically changing with a resource-specific offset. The divisor can be used to control the speed of changes.
        state = Math.sin(id.hashCode() + new Date()/1000) < 0; 
      else if ("l" in dictArgv && id in dictArgv["l"])
        // luminance sensor:
        // periodically changing with a resource-specific offset. The divisor can be used to control the speed of changes.
        state = (Math.sin(id.hashCode() + new Date()/10000) + 1)/2;
      else {
        response.status(500);
        response.send("resource with unknown dynamic type: " + id);
        return;
      }
      break;
    case "ternary":
    case "binary":
      state = statesOfResources[id];
      break;
    default:
      response.status(500);
      response.send("resource " + id + " has unknown type " + typesOfResources[id]);
      return;
  }

  switch (typeof state) {
    case "string":
    case "boolean":
      if (state === true || state === "on") {
        if (("s" in dictArgv && id in dictArgv["s"])
            || ("b" in dictArgv && id in dictArgv["b"]))
          // switches and lights are the only actuable things
          response.sendGraph(actuablePropertyBaseGraphOn);
        else
          response.sendGraph(propertyBaseGraphOn);
      } else if (state === false || state === "off") {
        if (("s" in dictArgv && id in dictArgv["s"])
            || ("b" in dictArgv && id in dictArgv["b"]))
          // switches and lights are the only actuable things
          response.sendGraph(actuablePropertyBaseGraphOff);
        else
          response.sendGraph(propertyBaseGraphOff);
      } else if (state === "neutral")
        response.sendGraph(actuablePropertyBaseGraphNeutral);
      else
        response.status(500).send("resource " + id + " has unknown string/boolean state " + state);
      break;
    case "number":
      response.sendGraph(propertyBaseGraph.merge([new rdf.Triple(localIt,qudtNumericValue,new rdf.Literal(state,null,xsddouble))]))
      break;
    default:
      response.status(500).send("resource " + id + " has unknown state " + state);
      break;
  }
});

app.route("/:id").put(function(request, response) {

  var id = request.params.id;
  if (! (id in typesOfResources)) {
    response.sendStatus(404);
    return;
  }

  if (!(("s" in dictArgv && id in dictArgv["s"])
      || ("b" in dictArgv && id in dictArgv["b"]))) {
    response.status(400).send('Only lights and switches are actuable');
    return;
  }

  var statetriple;
  var targetStateTripleCount = 0;
  request.graph.filter(
    function(triple) {
      return triple.predicate.nominalValue === 'http://www.w3.org/1999/02/22-rdf-syntax-ns#value'
    }).forEach(function(triple) {
      ++targetStateTripleCount;
      statetriple = triple;
    });
  if (targetStateTripleCount === 0 || targetStateTripleCount > 1) {
    response.status(400);
    response.send('Please supply exactly one triple with desired state\n');
    return;
  }

  if (statetriple.object.interfaceName === 'NamedNode') {
    switch (statetriple.object.nominalValue) {
      case "https://w3id.org/saref#On":
        statesOfResources[id] = true;
        break;
      case "https://w3id.org/saref#Off":
        statesOfResources[id] = false;
        break;
      case "http://example.org/Neutral":
        statesOfResources[id] = "neutral";
        break;
      default:
        response.status(400);
        response.send('Please supply a triple with rdf:value as predicate and saref:Off or saref:On as object\n');
        return;
      }
  } else {
    response.status(400);
    response.send('Please supply a triple with rdf:value as predicate and saref:Off or saref:On as object\n');
    return;
  }
  response.sendStatus(204);
});


// Startup the server
var port = 8080;
app.listen(port, function () {
  console.log('SSN Property REST app listening on port ' + port);
});

// For finding the server in the network, some handy output on the console
console.log(require('os').networkInterfaces());

String.prototype.hashCode = function() {
  var hash = 0, i, chr;
  if (this.length === 0) return hash;
  for (i = 0; i < this.length; i++) {
    chr   = this.charCodeAt(i);
    hash  = ((hash << 5) - hash) + chr;
    hash |= 0; // Convert to 32bit integer
  }
  return hash;
};

