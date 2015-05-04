cmake_minimum_required(VERSION 2.8)

include(cmake/lib/BoostLibInstaller.cmake)

function(require_boost_libs req_boost_version req_boost_libs)
    message(STATUS "Require Boost Libs module started.")
    message(STATUS "Required Boost version: ${req_boost_version}")
    message(STATUS "Required libs: ${req_boost_libs}")

    # Finding installed boost version
    find_package(Boost ${req_boost_version} COMPONENTS ${req_boost_libs})
    if(Boost_FOUND)
        message(STATUS "Boost package found.")
        message(STATUS "Include dirs: ${Boost_INCLUDE_DIRS}")
        message(STATUS "Libraries: ${Boost_LIBRARIES}")
    else(Boost_FOUND)
        boost_lib_installer(${req_boost_version} "${req_boost_libs}")
    endif(Boost_FOUND)
endfunction(require_boost_libs)