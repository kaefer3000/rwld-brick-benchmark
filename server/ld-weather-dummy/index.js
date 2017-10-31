//
// Serves a fake weather report for Dublin
//
// CLI parameters:
//  * s = speedup factor
//  * p = port
//
// Author: kaefer3000
//

// Load the web framework
var express = require('express');
// Load the logger for the web framework
var logger = require('morgan');
// Load CLI parser
var minimist = require('minimist');

// Reading CLI
var argv = minimist(process.argv.slice(2));
var speedupFactor = typeof argv.speedup != "number" ? 1 : argv.speedup;

var startupTime = new Date();

// The root app
var app = express();

// configuring the app
app.set('case sensitive routing', true);
app.set('strict routing', true);
//app.use(logger('dev'));


app.get('/', function(request, response) {

  var now = new Date();

  if (speedupFactor < 1 || speedupFactor > 1) {
    var diff = now - startupTime;
    now = new Date(startupTime.getTime() + speedupFactor * diff);
  }

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

  // Personal experience:
  // Every four hours we go from cloudy to sunny
  var clouds = 0.3 * Math.sin(now.getTime() / (1000 * 60 * 60) * 4 * 2 * Math.PI)
    // The worst weather is in January, the best in August:
    // https://weatherspark.com/y/33845/Average-Weather-in-Dublin-Ireland-Year-Round
    + Math.sin((now.getMonth() - 5) / 12 * 2 * Math.PI) * 0.2 + 0.4;

  response.set({ 'Content-Type': 'application/ld+json' });
  response.json({
    "@context": {
      "name":    "http://www.w3.org/2000/01/rdf-schema#label",
      "id":      "http://www.example.org/openWeatherMapId",
      "sys":     "http://www.example.org/hasSunshineEvent",
      "dt":      "http://purl.org/dc/terms/created",
      "sunrise": { "@id": "http://schema.org/startEvent", "@type": "http://www.w3.org/2001/XMLSchema#dateTime" },
      "sunset":  { "@id": "http://schema.org/endEvent",   "@type": "http://www.w3.org/2001/XMLSchema#dateTime" },
      "clouds":  { "@id": "http://purl.org/ns/meteo#cloudCover", "@type": "http://www.w3.org/2001/XMLSchema#double" }, 
      "all":     "@value"
    },
    // sample JSON from
    // http://samples.openweathermap.org/data/2.5/weather?q=London,uk&appid=b1b15e88fa797225412429c1c50c122a1
    "coord": { "lon": lon_dublin_deg, "lat": lat_dublin_deg }, // adapted
    "weather": [{ "id": 300, "main": "Drizzle", "description": "light intensity drizzle", "icon": "09d"} ],
    "base": "stations",
    "main": { "temp": 280.32, "pressure": 1012, "humidity": 81, "temp_min": 279.15, "temp_max": 281.15 },
    "visibility": 10000,
    "wind": { "speed": 4.1,"deg": 80 },
    "clouds": { "all" : clouds },
    "dt": now.toISOString(), // adapted
    "sys": {
      "type": 1,
      "id": 5091,
      "message": 0.0103,
      "country": "IE", // adapted
      "sunrise": date_rise.toISOString(),
      "sunset" : date_set .toISOString()
    },
    "id": 7778677, // adapted
    "name": "Dublin", //adapted
    "cod": 200}
  );
});


// Startup the server
var port = typeof argv.p != "number" ? 8080 : argv.p ;
app.listen(port, function () {
  console.log('Weather API listening on port ' + port);
});

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

// For finding the server in the network, some handy output on the console
console.log(require('os').networkInterfaces());

