cmake_minimum_required(VERSION 2.8)

include(ExternalProject)
include(GetBoostLibB2Args)

#boost_lib_checkout_submo("${install_dir}" libs/core)
    #boost_lib_checkout_submo("${install_dir}" libs/detail)
    #boost_lib_checkout_submo("${install_dir}" libs/config)
    #boost_lib_checkout_submo("${install_dir}" libs/preprocessor)
    #boost_lib_checkout_submo("${install_dir}" libs/mpl)
    #boost_lib_checkout_submo("${install_dir}" libs/wave)
    #boost_lib_checkout_submo("${install_dir}" libs/assert)
    #boost_lib_checkout_submo("${install_dir}" libs/move)
    #boost_lib_checkout_submo("${install_dir}" libs/static_assert)
    #boost_lib_checkout_submo("${install_dir}" libs/range)
    #boost_lib_checkout_submo("${install_dir}" libs/type_traits)
    #boost_lib_checkout_submo("${install_dir}" libs/iterator)
    #boost_lib_checkout_submo("${install_dir}" libs/concept_check)
    #boost_lib_checkout_submo("${install_dir}" libs/utility)
    #boost_lib_checkout_submo("${install_dir}" libs/throw_exception)
    #boost_lib_checkout_submo("${install_dir}" libs/predef)
    #boost_lib_checkout_submo("${install_dir}" libs/exception)
    #boost_lib_checkout_submo("${install_dir}" libs/smart_ptr)

# Known dependencies
set(core_dep
    config
    detail
    preprocessor
    assert
    move
    static_assert
    range
    type_traits
    iterator
    concept_check
    utility
    throw_exception
    predef
    exception
    smart_ptr
    mpl
    ratio
    integer)
set(chrono_dep system)
set(coroutine_dep context system)
set(context_dep chrono thread)
set(filesystem_dep system)
set(graph_dep regex)
set(locale_dep system)
set(log_dep chrono date_time filesystem thread)
set(thread_dep chrono)
set(timer_dep chrono)
set(wave_dep chrono date_time filesystem thread)

# Must build list
# set(to_build_libs chrono context filesystem graph_parallel iostreams locale mpi

function(boost_lib_checkout_submo install_dir submo_path)
    file(GLOB submo_dir "${install_dir}/${submo_path}/*")
    list(LENGTH submo_dir submo_dir_len)
    if(submo_dir_len EQUAL 0)
        message(STATUS "Checking out subodule: ${submo_path}")
        execute_process(COMMAND "${GIT_EXECUTABLE}" submodule update --recursive --init "${submo_path}" WORKING_DIRECTORY ${install_dir} RESULT_VARIABLE err ERROR_VARIABLE err_msg)
        if(err)
            message(FATAL_ERROR "Git error:\n${err_msg}")
        endif(err)
    else()
        message(STATUS "Submodule ${submo_path} is already checked out.")
    endif()    
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
        execute_process(COMMAND "${GIT_EXECUTABLE}" clone --branch boost-${req_boost_version} --single-branch --depth 1 https://github.com/boostorg/boost.git "${install_dir}" RESULT_VARIABLE err ERROR_VARIABLE err_msg)
        if(err)
            message(FATAL_ERROR "Git error:\n${err_msg}")
        endif(err)
    else()
        message(STATUS "Boost repository exists.")
    endif()

    # Checkout Tools and Musthaves
    boost_lib_checkout_submo("${install_dir}" tools/build)
    boost_lib_checkout_submo("${install_dir}" tools/inspect)
    boost_lib_checkout_submo("${install_dir}" libs/wave) # this is required for some unknown reason for jam

    # Bootstrap
    if(WIN32)
        set(bootstrap bootstrap.bat)
        set(b2_command b2.exe)
        file(TO_CMAKE_PATH "${install_dir}/b2.exe" b2_path)
    else(WIN32)
        set(bootstrap sh bootstrap.sh)
        set(b2_command b2)
        file(TO_CMAKE_PATH "${install_dir}/b2" b2_path)
    endif(WIN32)
    if (NOT EXISTS "${b2_path}")
        message(STATUS "Bootstrapping ...")
        execute_process(COMMAND ${bootstrap} WORKING_DIRECTORY ${install_dir} RESULT_VARIABLE err OUTPUT_VARIABLE err_msg OUTPUT_QUIET)
        if(err)
            message(FATAL_ERROR "Bootstrap error:\n${err_msg}")
        endif(err)
    else()
        message(STATUS "b2 executable found.")
    endif()

    # Process libs
    get_boots_lib_b2_args()
    message(STATUS "b2 args: ${b2Args}")

    # Resolve dependency tree
    list(APPEND req_boost_libs core) # core dependencies
    foreach(i RANGE 5)
        foreach(lib ${req_boost_libs})
            list(APPEND req_boost_libs2 ${lib})
            list(APPEND req_boost_libs2 ${${lib}_dep})
        endforeach()
        list(REMOVE_DUPLICATES req_boost_libs2)
        set(req_boost_libs "${req_boost_libs2}")
    endforeach()

    foreach(lib ${req_boost_libs})
        message(STATUS "Resolving Boost library: ${lib}")

        # Init submodule
        boost_lib_checkout_submo("${install_dir}" libs/${lib})

        if (EXISTS "${install_dir}/libs/${lib}/build/")
            # Has source
            set(jam_lib boost_${lib}_jam)
            set(boost_lib boost_${lib})

            # Create lib
            ExternalProject_Add(
                  ${jam_lib}
                  STAMP_DIR ${CMAKE_BINARY_DIR}/boost-${req_boost_version}
                  SOURCE_DIR ${install_dir}
                  BINARY_DIR ${install_dir}
                  CONFIGURE_COMMAND ""
                  BUILD_COMMAND "${b2_command}" "${b2Args}" --with-${lib}
                  INSTALL_COMMAND ""
                  LOG_BUILD ON)

            add_library(${boost_lib} STATIC IMPORTED GLOBAL)

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

                set_target_properties(${boost_lib} PROPERTIES
                    IMPORTED_LOCATION_DEBUG ${install_dir}/stage/lib/libboost_${ComponentLibName}-${CompilerName}-mt-gd-${req_boost_version}.lib
                    IMPORTED_LOCATION ${install_dir}/stage/lib/libboost_${ComponentLibName}-${CompilerName}-mt-${req_boost_version}.lib
                    LINKER_LANGUAGE CXX)
            else()
                set_target_properties(${boost_lib} PROPERTIES
                    IMPORTED_LOCATION_DEBUG ${install_dir}/stage/lib/libboost_${ComponentLibName}-mt-gd.a
                    IMPORTED_LOCATION ${install_dir}/stage/lib/libboost_${ComponentLibName}-mt.a
                    LINKER_LANGUAGE CXX)
            endif()

            set_target_properties(${jam_lib} ${boost_lib} PROPERTIES
                LABELS Boost EXCLUDE_FROM_ALL TRUE)

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
    message(STATUS "Generating headers ...")
    execute_process(COMMAND ${b2_command} headers WORKING_DIRECTORY ${install_dir} RESULT_VARIABLE err OUTPUT_VARIABLE err_msg)
    if(err)
        message(FATAL_ERROR "b2 error:\n${err_msg}")
    endif(err)

    set(Boost_INCLUDE_DIRS "${install_dir}" PARENT_SCOPE)
    set(Boost_FOUND TRUE PARENT_SCOPE)

endfunction(boost_lib_installer)