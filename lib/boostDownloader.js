var _ = require("lodash");
var cmakejs = require("cmake-js");
var CMLog = cmakejs.CMLog;
var Bluebird = require("bluebird");
var fs = Bluebird.promisifyAll(require("fs-extra"));
var semver = require("semver");
var path = require("path");
var environment = cmakejs.environment;
var cli = require("cli");
var zlib = require("zlib");
var tar = require("tar");
var request = require("request");

function downloadTo(url, result) {
    return new Bluebird(function (resolve, reject) {
        request
            .get(url)
            .on('error', function (err) { reject(err); })
            .pipe(result);

        result.once("finish", function () { resolve(); });
    });
}

function BoostDownloader(options) {
    this.options = options;
    this.dir = path.join(environment.home, ".cmake-js", "boost");
    this.version = options.version;
    this.log = new CMLog(this.options);
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
                self.log.info("BOOST", "Boost found in '" + foundDir + "'.");
                return foundDir;
            }

            return self._download();
        });
};

BoostDownloader.prototype._download = function() {
    var self = this;
    self.log.verbose("BOOST", "Getting Boost releases.");
    var command = "git ls-remote --tags https://github.com/boostorg/boost.git";
    return new Bluebird(function(resolve, reject) {
        cli.exec(command,
            function (output) {
                var downloadVersion = null;
                if (output && output.length) {
                    output.forEach(function(line) {
                        var parts = line.split(/\s+/);
                        if (parts.length === 2) {
                            var relVersion = parts[1].substr("refs/tags/boost-".length);
                            self.log.verbose("BOOST", "Comparing version: " + relVersion);
                            if (semver.satisfies(relVersion, self.version)) {
                                self.log.verbose("Version OK.");
                                downloadVersion = relVersion;
                                return false;
                            }
                        }
                    });
                }
                if (downloadVersion) {
                    return self._downloadVersion(downloadVersion);
                }
                else {
                    reject(new Error("No releases found."));
                }
            },
            function (err, output) {
                if (err instanceof Error) {
                    reject(new Error(err.message + (output ? ("\n" + output) : "")));
                    return;
                }
                if (_.isArray(output) && output.length || err && err.message) {
                    reject(new Error("Git exec error: " + err.message || err));
                    return;
                }
                reject(new Error("Git exec error."));
            });
    });
};

BoostDownloader.prototype._downloadVersion = function(version) {
    var self = this;
    var downloadUrl = "https://github.com/boostorg/boost/archive/boost-" + version + ".tar.gz";
    var internalPath = path.join(this.dir, version);
    self.log.http("BOOST", "Downloading Boost main package: " + downloadUrl);

    var gunzip = zlib.createGunzip();
    var extracter = new tar.Extract({
        path: internalPath,
        strip: 1
    });

    var main = new Bluebird(function (resolve, reject) {
        extracter.once("end", function () {
            resolve();
        });
        extracter.once("error", function (err) { reject(err); });
        request
            .get(tarUrl)
            .on('error', function (err) { reject(err); })
            .pipe(gunzip)
            .pipe(extracter);
    });

    var submodules = main.then(function() {
        var task = [];
        task.push(self._downloadSubmo(version, path.join(internalPath, "tools"), "build"));
        task.push(self._downloadSubmo(version, path.join(internalPath, "tools"), "inspect"));
        var libsPath = path.join(internalPath, "libs");
        task.push(
            fs.readdirAsync(libsPath)
                .then(function(libs) {
                    var libTasks = [];
                    libs.forEach(function (lib) {
                        var fullLibPath = path.join(libsPath, lib);
                        var stat = fs.lstatSync(fullLibPath);
                        if (stat.isDirectory()) {
                            libTasks.push(self._downloadSubmo(version, fullLibPath, lib));
                        }
                    });
                    return Bluebird.all(libTasks);
                }));
        return Bluebird.all(task);
    });

    return submodules;
};