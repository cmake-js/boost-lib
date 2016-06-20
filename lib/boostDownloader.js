var _ = require("lodash");
var cmakejs = require("cmake-js");
var CMLog = cmakejs.CMLog;
var Bluebird = require("bluebird");
var fs = Bluebird.promisifyAll(require("fs-extra"));
var semver = require("semver");
var path = require("path");
var environment = cmakejs.environment;
var zlib = require("zlib");
var tar = require("tar");
var request = require("request");
var exec = require('child_process').exec;

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
    if (!this.version) {
        throw new Error("Version option expected!");
    }
    this.log = new CMLog(this.options);
}

BoostDownloader.prototype.ensureDownloaded = function () {
    var self = this;
    self.log.info("BOOST", "Searching for Boost " + self.version + " in '" + self.dir + "'.");
    return fs.mkdirpAsync(self.dir)
        .then(function () {
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
                            .then(function () {
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
        exec(command, function (err, stdout, stderr) {
            if (err) {
                reject(err);
                return;
            }
            if (stdout) {
                var output = stdout.split("\n");
                var downloadVersion = null;
                if (output && output.length) {
                    output.reverse();
                    _.forEach(output, function (line) {
                        var parts = line.split(/\s+/);
                        if (parts.length === 2) {
                            var relVersion = parts[1].substr("refs/tags/boost-".length);

                            // Fix error when a tag is not a valid semver, by validating first
                            var sv = semver.valid(relVersion);
                            if (sv) {
                                self.log.verbose("BOOST", "Comparing version: " + relVersion);
                                if (semver.satisfies(sv, self.version)) {
                                    self.log.verbose("BOOST", "Version OK.");
                                    downloadVersion = relVersion;
                                    return false;
                                }
                            }
                        }
                    });
                }
                if (downloadVersion) {
                    self._downloadVersion(downloadVersion)
                        .then(function (result) {
                            resolve(result);
                        })
                        .catch(function (e) {
                            reject(e);
                        });
                    return;
                }
            }
            reject(new Error("No releases found."));
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
        .then(function () {
            return new Bluebird(function (resolve, reject) {
                gunzip.once("error", function (err) { reject(err); });
                extracter.once("end", function () {
                    self.log.verbose("BOOST", "Downloaded: " + internalPath);
                    resolve();
                });
                extracter.once("error", function (err) { reject(err); });
                request
                    .get(downloadUrl)
                    .on("error", function (err) { reject(err); })
                    .pipe(gunzip)
                    .on("error", function (err) { reject(err); })
                    .pipe(extracter)
                    .on("error", function (err) { reject(err); });
            });
        })
        .then(function () {
            return self._downloadSubmodules(version, internalPath);
        })
        .then(function () {
            return internalPath;
        });
};

BoostDownloader.prototype._downloadSubmodules = function (version, internalPath) {
    var self = this;
    var task = [];
    self.log.verbose("BOOST", "Checking tools.");
    task.push(self._downloadSubmo(version, path.join(internalPath, "tools"), "build"));
    task.push(self._downloadSubmo(version, path.join(internalPath, "tools"), "inspect"));
    function downloadAt(libsPath, prefix) {
        var dirName = path.basename(libsPath);
        prefix = prefix || "";
        self.log.info("BOOST", "Downloading submodules of director '" + dirName + "'.");
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
                                self._downloadSubmo(version, libsPath, lib, prefix)
                                    .then(function (internalPath) {
                                        ++done;
                                        if (internalPath) {
                                            self.log.info("BOOST", ((done / libTasks.length) * 100).toFixed(1) + "% - submodule " + dirName + "/" + lib + " downloaded.");
                                        }
                                        else {
                                            self.log.verbose("BOOST", ((done / libTasks.length) * 100).toFixed(1) + "% - submodule " + dirName + "/" + lib + " exists.");
                                        }
                                    })
                                    .catch(function (e) {
                                        ++done;
                                        self.log.info("BOOST", ((done / libTasks.length) * 100).toFixed(1) + "% - submodule " + dirName + "/" + lib + " download error.");
                                        self.log.silly("BOOST", "Error: " + e.stack);
                                    }));
                        }
                    });
                    return Bluebird.all(libTasks);
                }));
        return Bluebird.all(task);
    }

    return downloadAt(path.join(internalPath, "libs"))
        .then(function () {
            return downloadAt(path.join(internalPath, "libs", "numeric"), "numeric_");
        });
};

BoostDownloader.prototype._downloadSubmo = function (version, internalPath, name, prefix) {
    var self = this;
    prefix = prefix || "";
    internalPath = path.join(internalPath, name);

    return fs.readdirAsync(internalPath)
        .then(function (entries) {
            if (entries && entries.length) {
                return;
            }

            var downloadUrl = "https://github.com/boostorg/" + prefix + name + "/archive/boost-" + version + ".tar.gz";
            self.log.http("BOOST", "Downloading: " + downloadUrl);

            var gunzip = zlib.createGunzip();
            var extracter = new tar.Extract({
                path: internalPath,
                strip: 1
            });

            return new Bluebird(function (resolve, reject) {
                gunzip.once("error", function (err) { reject(err); });
                extracter.once("end", function () {
                    resolve(internalPath);
                });
                extracter.once("error", function (err) { reject(err); });
                request
                    .get(downloadUrl)
                    .on("error", function (err) { reject(err); })
                    .pipe(gunzip)
                    .on("error", function (err) { reject(err); })
                    .pipe(extracter)
                    .on("error", function (err) { reject(err); });
            });
        });
};

module.exports = BoostDownloader;