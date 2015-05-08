# boost-lib (MIT)

# About

boos-lib is a [Boost](http://www.boost.org/) dependency manager for [CMake.js](https://www.npmjs.com/package/cmake-js) based native modules.

Everyone knowns about [Boost](http://www.boost.org/). It's the base of almost all C++ projects out there. But using it in native node addons was not so easy (until now). It's a huge download that can be accessible by navigating through the infamous Sourceforge Crapware Screens. After downloading, you will get the source files, bundled with Jam based build system that is impossible to integrate with node-gyp.

So, if you wanted to create a native node module with Boost dependency, then you had the only option that to write down somewhere in the readme that your module requires Boost 1.x, and that's it. Your module consumers had to install Boost 1.x, compile it, set some environment variables pointing to their installation, and hope for that works with your module. There is not a miracle that there is no Boost based native node module exists ... yet.

The good news there is hope. With CMake.js you can create native modules with Boost dependency. If your module consumer has the appropriate Boost version installed, then your module will use that. If not, then boost-lib module downloads Boost from Github, compiles the required libraries (only the required ones), and your module will use that installation. Everything is automatic and as fast as possible. A typical Boost installation with one required library takes about ~1.5 minutes, and that has to be done only once, any following module installations will use that deployment.

#### CMake.js

CMake.js is a Node.js/io.js native addon build tool which works exactly like node-gyp, but instead of gyp, it is based on [CMake build system](http://cmake.org). It's [on the npm](https://www.npmjs.com/package/cmake-js).

# Installation

```
npm install boost-lib
```

# Usage

In a nutshell. *(For more complete documentation please see [the tutorial](https://github.com/unbornchikken/cmake-js/wiki/TUTORIAL-04-Creating-CMake.js-based-native-modules-with-Boost-dependency).)*

## 1. Include

Install boost-lib module from npm.

```
npm install boost-lib --save
```

Enter the following into your project's root CMakeLists.txt file to include BoostLib CMake module:

```cmake
# Include BoostLib module
SET(CMAKE_MODULE_PATH  
    "${CMAKE_CURRENT_SOURCE_DIR}/node_modules/boost-lib/cmake")

include(BoostLib)
```

## 2. Require

This makes `require_boost_libs` function available. It has two arguments:

- in the first argument you have to specify required Boost library's semver specification like that you can use in package.json. For example to use Boost 1.58, enter `1.58.0`, to use Boost 1.57 or above, enter `">= 1.57.0"`. See [semver](https://www.npmjs.com/package/semver) modules's documentation for further details.
- in the second argument you can specify required Boost's to-be-compiled libraries separated by semicolon. Leave blank if you need header only libraries. For example to depend on Boost.coroutine and Boost.DateTime, enter `coroutine;date_time`.

Examples:

Boost 1.57 or above required with thread and context libraries:

```cmake
require_boost_libs(">= 1.57.0" thread;context)
```

Boost 1.58 required with header only libraries:

```cmake
require_boost_libs(1.57.0 "")
```

Known to-be-build Boost libraries so far:

- chrono
- coroutine
- context
- filesystem
- graph
- locale
- log
- system
- thread
- timer
- wave

Their internal dependencies are handled automatically. So if you're requireing coroutine which depends on context and system, you don't have to sepcify them all, only coroutine.

## 3. Use

Boost's include path should be registered by entering:

```cmake
include_directories(${Boost_INCLUDE_DIRS})
```

And you have to link your addon with Boost libraries:

```cmake
target_link_libraries(${PROJECT_NAME} ${CMAKE_JS_LIB};${Boost_LIBRARIES})
```

# Example and tutorial

The [tutorial](https://github.com/unbornchikken/cmake-js/wiki/TUTORIAL-04-Creating-CMake.js-based-native-modules-with-Boost-dependency) is about making the [example module](https://github.com/unbornchikken/cmake-js-tut-04-boost-module), which can be downloaded from there:

```
git clone https://github.com/unbornchikken/cmake-js-tut-04-boost-module
```
