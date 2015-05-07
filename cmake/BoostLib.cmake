cmake_minimum_required(VERSION 2.8)

include(BoostLibInstaller)

function(require_boost_libs req_boost_version req_boost_libs)
    message(STATUS "Require Boost Libs module started.")
    message(STATUS "Required Boost version: ${req_boost_version}")
    message(STATUS "Required libs: ${req_boost_libs}")

    # Finding installed boost version
    string(REGEX MATCH "^[0-9]+\\.[0-9]+\\.[0-9]+$" m "${req_boost_version}")
    if(NOT m STREQUAL "")
        find_package(Boost "${req_boost_version}" COMPONENTS "${req_boost_libs}")
        if(Boost_FOUND)
            message(STATUS "Boost package found.")
        else(Boost_FOUND)
            boost_lib_installer("${req_boost_version}" "${req_boost_libs}")
            message(STATUS "Boost installed.")
        endif(Boost_FOUND)
    endif()

    message(STATUS "Boost Include dirs: ${Boost_INCLUDE_DIRS}")
    message(STATUS "Boost Libraries: ${Boost_LIBRARIES}")

    # Results:
    set(Boost_FOUND ${Boost_FOUND} PARENT_SCOPE)
    set(Boost_INCLUDE_DIRS "${Boost_INCLUDE_DIRS}" PARENT_SCOPE)
    set(Boost_LIBRARIES "${Boost_LIBRARIES}" PARENT_SCOPE)
endfunction(require_boost_libs)