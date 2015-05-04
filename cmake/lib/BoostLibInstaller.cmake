cmake_minimum_required(VERSION 2.8)

include(ExternalProject)
include(cmake/lib/GetBoostLibB2Args.cmake)

# Known dependencies
set(chrono_dep system)
set(coroutine_dep context system)
set(filesystem_dep system)
set(graph_dep regex)
set(locale_dep system)
set(log_dep chrono date_time filesystem thread)
set(thread_dep chrono)
set(timer_dep chrono)
set(wave_dep chrono date_time filesystem thread)

function(boost_lib_checkout_submo install_dir submo_path)
    # TODO: Only if dir is empty!
    message(STATUS "Checking out subodule: ${submo_path}")
    execute_process(COMMAND "${GIT_EXECUTABLE}" submodule update --init "${submo_path}" WORKING_DIRECTORY ${install_dir} RESULT_VARIABLE err ERROR_VARIABLE err_msg)
    if(err)
        message(FATAL_ERROR "Git error:\n${err_msg}")
    endif(err)
endfunction(boost_lib_checkout_submo name)

function(boost_lib_installer req_boost_version req_boost_libs)
    message(STATUS "Boost Lib Installer starting.")

    # Resolving Git dependency
    find_package(Git)
    if(GIT_FOUND)
        message(STATUS "Git found: ${GIT_EXECUTABLE}")
    else(GIT_FOUND)
        message(FATAL_ERROR "Git is required for Boost library installer.")
    endif(GIT_FOUND)

    # Install dir
    if(WIN32)
        set(install_dir $ENV{USERPROFILE})
    else(WIN32)
        set(install_dir $ENV{HOME})
    endif(WIN32)
    file(TO_NATIVE_PATH "${install_dir}/.cmake-js/boost/${req_boost_version}" install_dir)

    message(STATUS "Boost Lib install dir: ${install_dir}")

    # Clone
    if(NOT EXISTS "${install_dir}/.git/")
        message(STATUS "Cloning Boost, please stand by ...")
        execute_process(COMMAND "${GIT_EXECUTABLE}" clone https://github.com/boostorg/boost.git "${install_dir}" --no-checkout RESULT_VARIABLE err ERROR_VARIABLE err_msg)
        if(err)
            message(FATAL_ERROR "Git error:\n${err_msg}")
        endif(err)
    else()
        message(STATUS "Boost repository exists.")
    endif()

    # Checkout
    message(STATUS "Checking out release boost-${req_boost_version}")
    execute_process(COMMAND "${GIT_EXECUTABLE}" checkout tags/boost-${req_boost_version} WORKING_DIRECTORY ${install_dir} RESULT_VARIABLE err ERROR_VARIABLE err_msg)
    if(err)
        message(FATAL_ERROR "Git error:\n${err_msg}")
    endif(err)

    # Checkout Tools
    boost_lib_checkout_submo("${install_dir}" tools/build)

    # Bootstrap
    if(WIN32)
        set(bootstrap bootstrap.bat)
        file(TO_NATIVE_PATH "${install_dir}/b2.exe" b2)
    else(WIN32)
        set(bootstrap sh bootstrap.sh)
        file(TO_NATIVE_PATH "${install_dir}/b2" b2)
    endif(WIN32)
    if (NOT EXISTS "${b2}")
        message(STATUS "Bootstrapping ...")
        execute_process(COMMAND ${bootstrap} WORKING_DIRECTORY ${install_dir} RESULT_VARIABLE err ERROR_VARIABLE err_msg OUTPUT_QUIET)
        if(err)
            message(FATAL_ERROR "Bootstrap error:\n${err_msg}")
        endif(err)
    else()
        message(STATUS "b2 executable found.")
    endif()

    # Process libs
    get_boots_lib_b2_args()
    message(STATUS "b2 args: ${b2Args}")

    foreach(lib ${req_boost_libs})
        list(APPEND req_boost_libs2 ${lib})
        list(APPEND req_boost_libs2 ${${lib}_dep})
    endforeach()

    list(REMOVE_DUPLICATES req_boost_libs2)

    set(req_boost_libs "${req_boost_libs2}")

    foreach(lib ${req_boost_libs})
        message(STATUS "Resolving Boost library: ${lib}")

        # Init submodule
        boost_lib_checkout_submo("${install_dir}" libs/${lib})

        if (EXISTS "${install_dir}/libs/${lib}/build/")

            # Create lib
            ExternalProject_Add(
                  boost-${lib}-build
                  PREFIX ${CMAKE_BINARY_DIR}/boost-${req_boost_version}
                  SOURCE_DIR ${install_dir}
                  BINARY_DIR ${install_dir}
                  CONFIGURE_COMMAND ""
                  BUILD_COMMAND "${b2}" "${b2Args}" --with-${lib}
                  INSTALL_COMMAND ""
                  LOG_BUILD ON)

            add_library(boost-${lib} STATIC IMPORTED GLOBAL)

            if(lib STREQUAL "test")
                set(ComponentLibName unit_test_framework)
            else()
                set(ComponentLibName ${lib})
            endif()

            if(MSVC)
                if(MSVC11)
                    set(CompilerName vc110)
                elseif(MSVC12)
                    set(CompilerName vc120)
                elseif(MSVC14)
                    set(CompilerName vc140)
                endif()

                set_target_properties(boost-${lib} PROPERTIES
                    IMPORTED_LOCATION_DEBUG ${install_dir}/stage/lib/libboost_${ComponentLibName}-${CompilerName}-mt-gd-${req_boost_version}.lib
                    IMPORTED_LOCATION ${install_dir}/stage/lib/libboost_${ComponentLibName}-${CompilerName}-mt-${req_boost_version}.lib
                    IMPORTED_LOCATION_RELWITHDEBINFO ${install_dir}/stage/lib/libboost_${ComponentLibName}-${CompilerName}-mt-${req_boost_version}.lib
                    IMPORTED_LOCATION_RELEASENOINLINE ${install_dir}/stage/lib/libboost_${ComponentLibName}-${CompilerName}-mt-${req_boost_version}.lib
                    LINKER_LANGUAGE CXX)
            else()
                set_target_properties(boost-${lib} PROPERTIES
                    IMPORTED_LOCATION ${install_dir}/stage/lib/libboost_${ComponentLibName}-mt.a
                    LINKER_LANGUAGE CXX)
            endif()

            set_target_properties(boost-${lib}-build boost-${lib} PROPERTIES
                LABELS Boost EXCLUDE_FROM_ALL TRUE)

            add_dependencies(boost-${lib} boost-${lib}-build)
            foreach(dep_lib ${${lib}_dep})
                message(STATUS "Setting boost-${lib} dependent on boost-${dep_lib}")
                add_dependencies(boost-${lib} boost-${dep_lib})
            endforeach()

            list(APPEND boost_libs boost-${lib})

        endif()

    endforeach()

    if(boost_libs)
        message(STATUS "Boost libs scheduled for build: ${boost_libs}")
        set(Boost_LIBRARIES "${boost_libs}" CACHE STRING "Boost Libraries" FORCE)
    endif()

    # b2 headers

    set(Boost_FOUND TRUE CACHE BOOL "Is Boost found" FORCE)

endfunction(boost_lib_installer)