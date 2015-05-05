var _ = require("lodash");
var IntLog = require("./intLog");
var Bluebird = require("bluebird");
var fs = Bluebird.promisifyAll(require("fs-extra"));
var semver = require("semver");
var path = require("path");

function BoostDownloader(options) {
    this.options = options;
    this.dir = options.directory;
    this.version = options.version;
    this.log = new IntLog(options);
}

BoostDownloader.prototype.ensureDownloaded = function() {
    var self = this;
    self.log.info("BOOST", "Searching for Boost " + self.version + " in '" + self.dir + "'.");
    return fs.readdirAsync(self.dir)
        .then(function(files) {
            var foundDir = null;
            files.forEach(function(entry) {
                var fullPath = path.join(self.dir, entry);
                var stat = fs.lstatSync(fullPath);
                if (stat.isDirectory()) {
                    var sv = semver.valid(entry);
                    if (sv) {
                        self.log.verbose("BOOST", "Comparing version: " + sv)
                        if (semver.satisfies(sv, self.version)) {
                            foundDir = fullPath;
                            return false;
                        }
                    }
                }
            });
            return foundDir;
        })
        .then(function(foundDir) {
            if (foundDir) {
                return foundDir;
            }

            return self._download();
        });
};

BoostDownloader.prototype._download = function() {
    // git ls-remote --tags https://github.com/boostorg/boost.git - list tags
};