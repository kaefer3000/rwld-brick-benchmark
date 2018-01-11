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

var speedupFactor = typeof argv.speedup != "number" ? 1 : argv.speedup;

var startupTime = new Date();

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
                      new rdf.Literal('on'));
var offTriple = new rdf.Triple(
                      new rdf.NamedNode('#it'),
                      new rdf.NamedNode('http://www.w3.org/1999/02/22-rdf-syntax-ns#value'),
                      new rdf.Literal('off'));
var neutralTriple = new rdf.Triple(
                      new rdf.NamedNode('#it'),
                      new rdf.NamedNode('http://www.w3.org/1999/02/22-rdf-syntax-ns#value'),
                      new rdf.Literal('neutral'));
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
      if ("o" in dictArgv && id in dictArgv["o"]) {
        // occupancy sensor:
        // periodically changing with a resource-specific offset. The divisor can be used to control the speed of changes.
        state = Math.sin(id.hashCode() + new Date()/1000) < 0; 
        if (speedupFactor < 1 || speedupFactor > 1) {
        var diff = now - startupTime;
          now = new Date(startupTime.getTime() + speedupFactor * diff);
        }
        state = isPresent(id.hashCode(), now.getHours(), now.getMinutes());
     } 
     else if ("l" in dictArgv && id in dictArgv["l"]) {
        // luminance sensor:
        // periodically changing with a resource-specific offset. The divisor can be used to control the speed of changes.
        state = (Math.sin(id.hashCode() + new Date()/10000) + 1)/2;
        var now = new Date();

        if (speedupFactor < 1 || speedupFactor > 1) {
        var diff = now - startupTime;
          now = new Date(startupTime.getTime() + speedupFactor * diff);
        }
        state = calculateLuminance(id.hashCode() % 2 === 1, now);
      }
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

  if (statetriple.object.interfaceName === 'Literal') {
    switch (statetriple.object.nominalValue) {
      case "on":
        statesOfResources[id] = true;
        break;
      case "off":
        statesOfResources[id] = false;
        break;
      case "neutral":
        statesOfResources[id] = "neutral";
        break;
      default:
        response.status(400);
        response.send('Please supply a triple with rdf:value as predicate and off, on, or neutral as object\n');
        return;
      }
  } else {
    response.status(400);
    response.send('Please supply a triple with rdf:value as predicate and off, on, or neutral as object\n');
    return;
  }
  response.sendStatus(204);
});


// Startup the server
var port = typeof argv.p != "number" ? 8080 : argv.p ;
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

var mar = "mar"
var jun = "jun"
var sep = "sep"
var dec = "dec"

var w = "w"
var e = "e"

var cloudy = "cloudy"
var clear  = "clear"

var illuminance = {
  // Values for Annette, AK, USA
  // Annette, AK, USA, lat: 53.03°N, long: 131.57°W has the closest match to Dublin's latitude
  // from "Solar Radiation Data Manual" by W. Marion and S. Wilcox, National Renewable Energy Laboratory (NREL), 1995
  mar: { e : { 9 : { clear: 64, cloudy: 17 } , 11 : { clear: 43, cloudy: 20 }, 13 : { clear: 11, cloudy: 12 }, 15: { clear: 10, cloudy:  9 }, 17 : { clear:  5, cloudy:  4 } },
         w : { 9 : { clear:  8, cloudy:  7 } , 11 : { clear: 11, cloudy: 11 }, 13 : { clear: 25, cloudy: 16 }, 15: { clear: 60, cloudy: 20 }, 17 : { clear: 46, cloudy: 12 } } },
  jun: { e : { 9 : { clear: 83, cloudy: 29 } , 11 : { clear: 64, cloudy: 32 }, 13 : { clear: 21, cloudy: 19 }, 15: { clear: 15, cloudy: 17 }, 17 : { clear: 12, cloudy: 13 } },
         w : { 9 : { clear: 11, cloudy: 12 } , 11 : { clear: 14, cloudy: 16 }, 13 : { clear: 15, cloudy: 17 }, 15: { clear: 54, cloudy: 32 }, 17 : { clear: 80, cloudy: 36 } } },
  sep: { e : { 9 : { clear: 68, cloudy: 17 } , 11 : { clear: 60, cloudy: 23 }, 13 : { clear: 17, cloudy: 14 }, 15: { clear: 12, cloudy: 12 }, 17 : { clear:  8, cloudy:  8 } },
         w : { 9 : { clear:  8, cloudy:  6 } , 11 : { clear: 11, cloudy: 11 }, 13 : { clear: 13, cloudy: 12 }, 15: { clear: 53, cloudy: 24 }, 17 : { clear: 69, cloudy: 21 } } },
  dec: { e : { 9 : { clear:  4, cloudy:  1 } , 11 : { clear: 20, cloudy:  6 }, 13 : { clear:  6, cloudy:  4 }, 15: { clear:  2, cloudy:  1 }, 17 : { clear:  0, cloudy:  0 } },
         w : { 9 : { clear:  0, cloudy:  0 } , 11 : { clear:  5, cloudy:  4 }, 13 : { clear: 16, cloudy:  6 }, 15: { clear: 18, cloudy:  3 }, 17 : { clear:  0, cloudy:  0 } } }
};

calculateLuminance = function(westwards, now) {

  var yearsFirst = new Date(now.getFullYear(), 0, 0);
  var dayOfYear = Math.floor(((now - yearsFirst) + ((yearsFirst.getTimezoneOffset() - now.getTimezoneOffset()) * 60 * 1000))/(1000*60*60*24));

  var lon_dublin_deg = -6.266155;
  var lat_dublin_deg = 53.350140;

//Implementation of the algorithm from http://www.edwilliams.org/sunrise_sunset_algorithm.htm in JavaScript for both sunrise and sunset
//
//Sunrise/Sunset Algorithm

//Source:
//	Almanac for Computers, 1990
//	published by Nautical Almanac Office
//	United States Naval Observatory
//	Washington, DC 20392

//Inputs:
//	day, month, year:      date of sunrise/sunset
//	latitude, longitude:   location for sunrise/sunset
	var zenith //:                Sun's zenith for sunrise/sunset
	  = offical      = 90 + 50/60 // degrees 50'
//	  civil        = 96 degrees
//	  nautical     = 102 degrees
//	  astronomical = 108 degrees
	
//	NOTE: longitude is positive for East and negative for West
//        NOTE: the algorithm assumes the use of a calculator with the
//        trig functions in "degree" (rather than "radian") mode. Most
//        programming languages assume radian arguments, requiring back
//        and forth convertions. The factor is 180/pi. So, for instance,
//        the equation RA = atan(0.91764 * tan(L)) would be coded as RA
//        = (180/pi)*atan(0.91764 * tan((pi/180)*L)) to give a degree
//        answer with a degree input for L.


// 1. first calculate the day of the year

//	N1 = floor(275 * month / 9)
//	N2 = floor((month + 9) / 12)
//	N3 = (1 + floor((year - 4 * floor(year / 4) + 2) / 3))
// 	N = N1 - (N2 * N3) + day - 30
	var N = dayOfYear

// 2. convert the longitude to hour value and calculate an approximate time

	var lngHour = lon_dublin_deg / 15
	
//	if rising time is desired:
	var t_rise = N + ((6 - lngHour) / 24)
//	if setting time is desired:
	var t_set = N + ((18 - lngHour) / 24)

// 3. calculate the Sun's mean anomaly
	
	var M_rise = (0.9856 * t_rise) - 3.289
	var M_set  = (0.9856 * t_set ) - 3.289

// 4. calculate the Sun's true longitude
	
	var L_rise = M_rise + (1.916 * Math.sin(rad_from_deg(M_rise))) + (0.020 * Math.sin(2 * rad_from_deg(M_rise))) + 282.634
	var L_set  = M_set  + (1.916 * Math.sin(rad_from_deg(M_set ))) + (0.020 * Math.sin(2 * rad_from_deg(M_set ))) + 282.634

//	NOTE: L potentially needs to be adjusted into the range [0,360) by adding/subtracting 360
        L_rise = adjustIntoNonNegativeBelow(360, L_rise);
        L_set  = adjustIntoNonNegativeBelow(360, L_set );


// 5a. calculate the Sun's right ascension
	
	var RA_rise = deg_from_rad(Math.atan(0.91764 * Math.tan(rad_from_deg(L_rise))))
	var RA_set  = deg_from_rad(Math.atan(0.91764 * Math.tan(rad_from_deg(L_set ))))

//	NOTE: RA potentially needs to be adjusted into the range [0,360) by adding/subtracting 360
	RA_rise = adjustIntoNonNegativeBelow(360, RA_rise);
	RA_set  = adjustIntoNonNegativeBelow(360, RA_set );

// 5b. right ascension value needs to be in the same quadrant as L

	var Lquadrant_rise  = (Math.floor( L_rise/90)) * 90
	var Lquadrant_set   = (Math.floor( L_set /90)) * 90
	var RAquadrant_rise = (Math.floor(RA_rise/90)) * 90
	var RAquadrant_set  = (Math.floor(RA_set /90)) * 90
	RA_rise = RA_rise + (Lquadrant_rise - RAquadrant_rise)
	RA_set  = RA_set  + (Lquadrant_set  - RAquadrant_set )

// 5c. right ascension value needs to be converted into hours

	RA_rise = RA_rise / 15
	RA_set  = RA_set  / 15

// 6. calculate the Sun's declination

	var sinDec_rise = 0.39782 * Math.sin(rad_from_deg(L_rise))
	var sinDec_set  = 0.39782 * Math.sin(rad_from_deg(L_set ))
	var cosDec_rise = Math.cos(Math.asin(sinDec_rise))
	var cosDec_set  = Math.cos(Math.asin(sinDec_set ))

// 7a. calculate the Sun's local hour angle
	
	var cosH_rise = (Math.cos(rad_from_deg(zenith)) - (sinDec_rise * Math.sin(rad_from_deg(lat_dublin_deg)))) / (cosDec_rise * Math.cos(rad_from_deg(lat_dublin_deg)))
	var cosH_set  = (Math.cos(rad_from_deg(zenith)) - (sinDec_set  * Math.sin(rad_from_deg(lat_dublin_deg)))) / (cosDec_set  * Math.cos(rad_from_deg(lat_dublin_deg)))
	
//	if (cosH >  1)
//	  the sun never rises on this location (on the specified date)
//	if (cosH < -1)
//	  the sun never sets on this location (on the specified date)

// 7b. finish calculating H and convert into hours
	
//	if rising time is desired:
	var H_rise = 360 - deg_from_rad(Math.acos(cosH_rise))
//	if setting time is desired:
	var H_set  = deg_from_rad(Math.acos(cosH_set))
	
	H_rise = H_rise / 15
	H_set  = H_set  / 15

// 8. calculate local mean time of rising/setting
	
	var T_rise = H_rise + RA_rise - (0.06571 * t_rise) - 6.622
	var T_set  = H_set  + RA_set  - (0.06571 * t_set ) - 6.622

// 9. adjust back to UTC

	var UT_rise = T_rise - lngHour
	var UT_set  = T_set  - lngHour

// 	NOTE: UT potentially needs to be adjusted into the range [0,24) by adding/subtracting 24
	var UT_rise = adjustIntoNonNegativeBelow(24, UT_rise);
	var UT_set  = adjustIntoNonNegativeBelow(24, UT_set );

// 10. convert UT value to local time zone of latitude/longitude
	
	var localT_rise = UT_rise - new Date().getTimezoneOffset() / 60
	var localT_set  = UT_set  - new Date().getTimezoneOffset() / 60

  var date_rise = new Date(new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() + localT_rise * 60 * 60 * 1000)
  var date_set  = new Date(new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() + localT_set  * 60 * 60 * 1000)

  if (now < date_rise) return 0;
  if (now > date_set)  return 0;

  // Personal experience:
  // Every four hours we go from cloudy to sunny
  var clouds = 0.3 * Math.sin(now.getTime() / (1000 * 60 * 60) * 4 * 2 * Math.PI)
    // The worst weather is in January, the best in August:
    // https://weatherspark.com/y/33845/Average-Weather-in-Dublin-Ireland-Year-Round
    + Math.sin((now.getMonth() - 5) / 12 * 2 * Math.PI) * 0.2 + 0.4;

  var cloudySky = clouds > 0.5;

  var hour = now.getHours();
  var hourInTable;
  var month = now.getMonth() + 1; // because January is 0
  var monthInTable;

  // preparing for table lookup of hour
  if (hour <= 10)
    hourInTable = 9;
  else if (hour <= 12)
    hourInTable = 11;
  else if (hour <= 14)
    hourInTable = 13;
  else if (hour <= 16)
    hourInTable = 15;
  else
    hourInTable = 17;

  // preparing for table lookup of month
  if (month < 3 || month === 12)
    monthInTable = dec;
  else if (month < 6)
    monthInTable = mar;
  else if (month < 9)
    monthInTable = jun;
  else
    monthInTable = sep;

  var orientation = westwards ? w : e;
  var cloudiness = cloudySky ? cloudy : clear;

  return illuminance[monthInTable][orientation][hourInTable][cloudiness] / 100;

};

rad_from_deg = function(deg) { return deg * (Math.PI / 180); };
deg_from_rad = function(rad) { return rad * (180 / Math.PI); };

adjustIntoNonNegativeBelow = function(limit, number) {
  if (number < 0)
    return number + limit;
  else if (number >= limit)
    return number - limit;
  else
    return number;
};


isPresent = function(roomid, hour, minute) {

  // Implementing Figures 13+14 of Chang and Hong: "Statistical analysis and modeling of occupancy patterns in open-plan offices using measured lighting-switch data", In: Building Simulation 6:1 (2013)
  if (hour < 8 || hour > 18)
    return false;

  switch (roomid % 6) {
    case 0:
      if (hour === 9 && minute > 45)
        return false;
      else
        return true;
      break;
    case 1:
      if (hour === 10 || (hour === 14 && minute < 10))
        return false;
      else
        return true;
      break;
    case 2:
      if (hour === 15 && minute < 15)
        return false;
      else
        return true;
      break;
    case 3:
      if ((hour === 9 && minute > 30) || (hour === 10 && minute < 30) || (hour === 12 && minute < 30) || hour === 13 || (hour === 14 && minute < 30) || (hour === 17 && (minute > 30 || minute < 35)))
        return false;
      else
        return true;
      break;
    case 4:
      if ((hour === 10 && minute < 5)  || (hour === 11 && minute > 30) || (hour === 17 && minute < 30))
        return false;
      else
        return true;
      break;
    case 5:
      if ((hour === 11 && minute < 30) || (hour === 12 && minute < 30) || (hour === 16 && minute < 10) || (hour === 17 && minute < 10))
        return false;
      else
        return true;
      break;
    default:
      console.log("modulo operator gone wild");
  }
};

