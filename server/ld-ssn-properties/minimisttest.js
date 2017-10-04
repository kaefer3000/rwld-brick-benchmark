var argv = require('minimist')(process.argv.slice(2));
console.log("x" in argv);
console.dir(argv);
