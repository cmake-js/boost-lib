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

function downloadTo (url, result) {
    return new Bluebird(function (resolve, reject) {
        request
            .get(url)
            .on('error', function (err) { reject(err); })
            .pipe(result);

        result.once("finish", function () { resolve(); });
    });
}

function BoostDownloader (options) {
    this.options = options;
    this.dir = path.join(environment.home, ".cmake-js", "boost");
    this.version = options.version;
    if (!this.version) {
        throw new Error("Version option expected!");
    }
    this.log = new CMLog(this.options);
}

BoostDownloader.prototype.ensureDownloaded = function () {
    var self = this;
    self.log.info("BOOST", "Searching for Boost " + self.version + " in '" + self.dir + "'.");
    return fs.mkdirpAsync(self.dir)
        .then(function() {
            return fs.readdirAsync(self.dir)
        })
        .then(function (files) {
            self.log.silly("BOOST", files.length + " entries found.");
            var foundDir = null;
            _.forEach(files, function (entry) {
                var fullPath = path.join(self.dir, entry);
                var stat = fs.lstatSync(fullPath);
                if (stat.isDirectory()) {
                    var sv = semver.valid(entry);
                    if (sv) {
                        self.log.verbose("BOOST", "Comparing version: " + sv);
                        if (semver.satisfies(sv, self.version)) {
                            foundDir = fullPath;
                            return false;
                        }
                    }
                }
            });
            return foundDir;
        })
        .then(function (foundDir) {
            if (foundDir) {
                self.log.info("BOOST", "Boost found in '" + foundDir + "'.");

                var stat;

                // Is this already initialized?
                try {
                    stat = fs.statSync(path.join(foundDir, environment.isWin ? "b2.exe" : "b2"));
                    if (stat.isFile()) {
                        self.log.verbose("BOOST", "Deployment already initialized.");
                        return foundDir;
                    }
                }
                catch (e) {
                }

                // Is this already downloaded?
                try {
                    stat = fs.statSync(path.join(foundDir, environment.isWin ? "bootstrap.bat" : "bootstrap.sh"));
                    if (stat.isFile()) {
                        self.log.verbose("BOOST", "Deployment already downloaded. Checking submodules.");
                        return self._downloadSubmodules(semver.valid(path.basename(foundDir)), foundDir)
                            .then(function() {
                                return foundDir;
                            });
                    }
                }
                catch (e) {
                }
            }

            return self._download();
        });
};

BoostDownloader.prototype._download = function () {
    var self = this;
    self.log.verbose("BOOST", "Getting Boost releases.");
    var command = "git ls-remote --tags https://github.com/boostorg/boost.git";
    return new Bluebird(function (resolve, reject) {
        cli.exec(command,
            function (output) {
                var downloadVersion = null;
                if (output && output.length) {
                    output.reverse();
                    _.forEach(output, function (line) {
                        var parts = line.split(/\s+/);
                        if (parts.length === 2) {
                            var relVersion = parts[1].substr("refs/tags/boost-".length);
                            self.log.verbose("BOOST", "Comparing version: " + relVersion);
                            if (semver.satisfies(relVersion, self.version)) {
                                self.log.verbose("BOOST", "Version OK.");
                                downloadVersion = relVersion;
                                return false;
                            }
                        }
                    });
                }
                if (downloadVersion) {
                    self._downloadVersion(downloadVersion)
                        .then(function(result) {
                            resolve(result);
                        })
                        .catch(function(e) {
                            reject(e);
                        });
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

BoostDownloader.prototype._downloadVersion = function (version) {
    var self = this;
    var downloadUrl = "https://github.com/boostorg/boost/archive/boost-" + version + ".tar.gz";
    var internalPath = path.join(this.dir, version);
    self.log.http("BOOST", "Downloading: " + downloadUrl);

    var gunzip = zlib.createGunzip();
    var extracter = new tar.Extract({
        path: internalPath,
        strip: 1
    });

    return fs.mkdirpAsync(internalPath)
        .then(function() {
            return new Bluebird(function (resolve, reject) {
                extracter.once("end", function () {
                    self.log.verbose("BOOST", "Downloaded: " + internalPath);
                    resolve();
                });
                extracter.once("error", function (err) { reject(err); });
                request
                    .get(downloadUrl)
                    .on('error', function (err) { reject(err); })
                    .pipe(gunzip)
                    .pipe(extracter);
            });
        })
        .then(function () {
            return self._downloadSubmodules(version, internalPath);
        })
        .then(function() {
            return internalPath;
        });
};

BoostDownloader.prototype._downloadSubmodules = function (version, internalPath) {
    var self = this;
    var task = [];
    self.log.verbose("BOOST", "Checking tools.");
    task.push(self._downloadSubmo(version, path.join(internalPath, "tools"), "build"));
    task.push(self._downloadSubmo(version, path.join(internalPath, "tools"), "inspect"));
    var libsPath = path.join(internalPath, "libs");
    var done = 0;
    task.push(
        fs.readdirAsync(libsPath)
            .then(function (libs) {
                self.log.verbose("BOOST", "Checking " + libs.length + " libs.");
                var libTasks = [];
                libs.forEach(function (lib) {
                    var fullLibPath = path.join(libsPath, lib);
                    var stat = fs.lstatSync(fullLibPath);
                    if (stat.isDirectory()) {
                        libTasks.push(
                            self._downloadSubmo(version, libsPath, lib)
                                .then(function(internalPath) {
                                    ++done;
                                    if (internalPath) {
                                        self.log.info("BOOST", ((done / libTasks.length) * 100).toFixed(1) + "% - Downloaded: " + internalPath);
                                    }
                                    else {
                                        self.log.verbose("BOOST", ((done / libTasks.length) * 100).toFixed(1) + "% - submodule " + lib + " exists.");
                                    }
                                }));
                    }
                });
                return Bluebird.all(libTasks);
            }));
    return Bluebird.all(task);
};

BoostDownloader.prototype._downloadSubmo = function (version, internalPath, name) {
    var self = this;
    internalPath = path.join(internalPath, name);

    return fs.readdirAsync(internalPath)
        .then(function(entries) {
            if (entries && entries.length) {
                return;
            }

            var downloadUrl = "https://github.com/boostorg/" + name + "/archive/boost-" + version + ".tar.gz";
            self.log.http("BOOST", "Downloading: " + downloadUrl);

            var gunzip = zlib.createGunzip();
            var extracter = new tar.Extract({
                path: internalPath,
                strip: 1
            });

            return new Bluebird(function (resolve, reject) {
                extracter.once("end", function () {
                    resolve(internalPath);
                });
                extracter.once("error", function (err) { reject(err); });
                request
                    .get(downloadUrl)
                    .on('error', function (err) { reject(err); })
                    .pipe(gunzip)
                    .pipe(extracter);
            });
        });
};

module.exports = BoostDownloader;