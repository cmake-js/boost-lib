cmake_minimum_required(VERSION 3.2)

include(ExternalProject)
include(GetBoostLibB2Args)
include(DownloadBoost)

# Known dependencies
set(chrono_dep system)
set(coroutine_dep context system)
set(context_dep thread)
set(filesystem_dep system)
set(graph_dep regex)
set(locale_dep system)
set(log_dep chrono date_time filesystem thread)
set(thread_dep chrono)
set(timer_dep chrono)
set(wave_dep chrono date_time filesystem thread)

function(boost_lib_installer req_boost_version req_boost_libs)
    message(STATUS "Boost Lib Installer starting.")

    # Download
    download_boost("${req_boost_version}")
    get_filename_component(req_boost_version "${install_dir}" NAME)
    message(STATUS "Boost path: ${install_dir}")
    message(STATUS "Boost version: ${req_boost_version}")
    string(REGEX MATCH "^([0-9]+)\\.([0-9]+)\\." m "${req_boost_version}")
    set(lib_postfix "${CMAKE_MATCH_1}_${CMAKE_MATCH_2}")
    message(STATUS "Boost library postfix: ${lib_postfix}")

    # Bootstrap
    if(WIN32)
        set(bootstrap bootstrap.bat)
        set(b2_command b2.exe)
        file(TO_CMAKE_PATH "${install_dir}/b2.exe" b2_path)
    else(WIN32)
        set(bootstrap ./bootstrap.sh)
        set(b2_command ./b2)
        file(TO_CMAKE_PATH "${install_dir}/b2" b2_path)
    endif(WIN32)
    if (NOT EXISTS "${b2_path}")
        message(STATUS "Invoking ${install_dir}/tools/build/${bootstrap}")
        execute_process(COMMAND "${bootstrap}" WORKING_DIRECTORY "${install_dir}/tools/build" RESULT_VARIABLE err OUTPUT_VARIABLE err_msg OUTPUT_QUIET)
        if(err)
            message(FATAL_ERROR "Bootstrap error:\n${err_msg}")
        endif(err)
        message(STATUS "Invoking ${install_dir}/${bootstrap}")
        execute_process(COMMAND "${bootstrap}" WORKING_DIRECTORY "${install_dir}" RESULT_VARIABLE err OUTPUT_VARIABLE err_msg OUTPUT_QUIET)
        if(err)
            message(FATAL_ERROR "Bootstrap error:\n${err_msg}")
        endif(err)
    else()
        message(STATUS "b2 executable found.")
    endif()

    # Process libs
    if(MSVC)
        if(CMAKE_CL_64 EQUAL 1)
            set(stage_dir stage64)
        else()
            set(stage_dir stage32)
        endif()
    else()
        set(stage_dir stage)
    endif()
    
    get_boots_lib_b2_args()
    message(STATUS "b2 args: ${b2Args}")

    # Resolve dependency tree
    foreach(i RANGE 4)
        foreach(lib ${req_boost_libs})
            list(APPEND req_boost_libs2 ${lib})
            list(APPEND req_boost_libs2 ${${lib}_dep})
        endforeach()
        list(REMOVE_DUPLICATES req_boost_libs2)
        set(req_boost_libs "${req_boost_libs2}")
    endforeach()

    foreach(lib ${req_boost_libs})
        message(STATUS "Resolving Boost library: ${lib}")

        if (EXISTS "${install_dir}/libs/${lib}/build/")
            # Has source
            
            # Setup variables
            set(jam_lib boost_${lib}_jam)
            set(boost_lib boost_${lib})
            if(lib STREQUAL "test")
                set(lib_name unit_test_framework)
            else()
                set(lib_name ${lib})
            endif()
            
            if(MSVC)
                if(MSVC11)
                    set(compiler_name vc110)
                elseif(MSVC12)
                    set(compiler_name vc120)
                elseif(MSVC14)
                    set(compiler_name vc140)
                endif()
                
                set(debug_lib_path "${install_dir}/${stage_dir}/lib/libboost_${lib_name}-${compiler_name}-mt-gd-${lib_postfix}.lib")
                set(lib_path "${install_dir}/${stage_dir}/lib/libboost_${lib_name}-${compiler_name}-mt-${lib_postfix}.lib")
            else()
                if((CMAKE_BUILD_TYPE STREQUAL "Debug") OR (CMAKE_BUILD_TYPE STREQUAL "") OR (NOT DEFINED CMAKE_BUILD_TYPE))
                    set(lib_path "${install_dir}/${stage_dir}/lib/libboost_${lib_name}-mt-d.a")
                else()
                    set(lib_path "${install_dir}/${stage_dir}/lib/libboost_${lib_name}-mt.a")
                endif()
            endif()

            # Create lib
            if(EXISTS ${lib_path})
                message(STATUS "Library ${lib} already built.")
                # Dummy project:
                ExternalProject_Add(
                    "${jam_lib}"
                    STAMP_DIR "${CMAKE_BINARY_DIR}/boost-${req_boost_version}"
                    SOURCE_DIR "${install_dir}"
                    BINARY_DIR "${install_dir}"
                    CONFIGURE_COMMAND ""
                    BUILD_COMMAND ""
                    INSTALL_COMMAND ""
                    BUILD_BYPRODUCTS "${lib_path}"
                    LOG_BUILD OFF)
            else()
                message(STATUS "Setting up external project to build ${lib}.")
                ExternalProject_Add(
                    "${jam_lib}"
                    STAMP_DIR "${CMAKE_BINARY_DIR}/boost-${req_boost_version}"
                    SOURCE_DIR "${install_dir}"
                    BINARY_DIR "${install_dir}"
                    CONFIGURE_COMMAND ""
                    BUILD_COMMAND "${b2_command}" "${b2Args}" --with-${lib}
                    INSTALL_COMMAND ""
                    BUILD_BYPRODUCTS "${lib_path}"
                    LOG_BUILD ON)
            endif()            

            add_library(${boost_lib} STATIC IMPORTED GLOBAL)            

            if(MSVC)
                set_target_properties(${boost_lib} PROPERTIES
                    IMPORTED_LOCATION_DEBUG "${debug_lib_path}"
                    IMPORTED_LOCATION "${lib_path}"
                    LINKER_LANGUAGE CXX)
            else()
                set_target_properties(${boost_lib} PROPERTIES
                    IMPORTED_LOCATION "${lib_path}"
                    LINKER_LANGUAGE CXX)
            endif()

            # Exlude it from all
            set_target_properties(${jam_lib} ${boost_lib} PROPERTIES LABELS Boost EXCLUDE_FROM_ALL TRUE)

            # Setup dependencies
            add_dependencies(${boost_lib} ${jam_lib})
            foreach(dep_lib ${${lib}_dep})
                message(STATUS "Setting ${boost_lib} dependent on boost_${dep_lib}")
                add_dependencies(${boost_lib} boost_${dep_lib})
            endforeach()

            list(APPEND boost_libs ${boost_lib})

        endif()

    endforeach()

    if(boost_libs)
        message(STATUS "Boost libs scheduled for build: ${boost_libs}")
        set(Boost_LIBRARIES "${boost_libs}" PARENT_SCOPE)
    else()
        set(Boost_LIBRARIES "" PARENT_SCOPE)
    endif()

    # b2 headers
    if(NOT EXISTS ${install_dir}/boost/)
        message(STATUS "Generating headers ...")
        execute_process(COMMAND ${b2_command} headers WORKING_DIRECTORY ${install_dir} RESULT_VARIABLE err OUTPUT_VARIABLE err_msg)
        if(err)
            message(FATAL_ERROR "b2 error:\n${err_msg}")
        endif(err)
    else()
        message(STATUS "Headers found.")
    endif()

    set(Boost_INCLUDE_DIRS "${install_dir}" PARENT_SCOPE)
    set(Boost_FOUND TRUE PARENT_SCOPE)

endfunction(boost_lib_installer)