cmake_minimum_required(VERSION 2.8)

include(cmake/lib/GetBoostLibB2Args.cmake)

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
        message(STATUS "Cloning Boost ...")
        execute_process(COMMAND "${GIT_EXECUTABLE}" clone https://github.com/boostorg/boost.git "${install_dir}" --no-checkout RESULT_VARIABLE err ERROR_VARIABLE err_msg)
        if(err)
            message(FATAL_ERROR "Git error:\n${err_msg}")
        endif(err)
    else()
        message(STATUS "Boost repository exists.")
    endif()

    # Checkout
    message(STATUS "Fetching Tags ...")
    execute_process(COMMAND "${GIT_EXECUTABLE}" fetch --tags WORKING_DIRECTORY ${install_dir} RESULT_VARIABLE err ERROR_VARIABLE err_msg)
    if(err)
        message(FATAL_ERROR "Git error:\n${err_msg}")
    endif(err)

    message(STATUS "Checking out release boost-${req_boost_version}")
    execute_process(COMMAND "${GIT_EXECUTABLE}" checkout tags/boost-${req_boost_version} WORKING_DIRECTORY ${install_dir} RESULT_VARIABLE err ERROR_VARIABLE err_msg)
    if(err)
        message(FATAL_ERROR "Git error:\n${err_msg}")
    endif(err)

    # Checkout Tools
    boost_lib_checkout_submo("${install_dir}" tools/build)

    # Bootstrap
    if(WIN32)
        set(bootstrap "bootstrap.bat")
        file(TO_NATIVE_PATH "${install_dir}/b2.exe" b2)
    else(WIN32)
        set(bootstrap "bootstrap.sh")
        file(TO_NATIVE_PATH "${install_dir}/b2" b2)
    endif(WIN32)
    if (NOT EXISTS "${b2}")
        message(STATUS "Bootstrapping ...")
        execute_process(COMMAND "${bootstrap}" WORKING_DIRECTORY ${install_dir} RESULT_VARIABLE err ERROR_VARIABLE err_msg OUTPUT_QUIET)
        if(err)
            message(FATAL_ERROR "Bootstrap error:\n${err_msg}")
        endif(err)
    else()
        message(STATUS "b2 executable found.")
    endif()

    # Foreach lib

    get_boots_lib_b2_args()
    message(STATUS "b2 args: ${b2Args}")

    foreach(lib ${req_boost_libs})
        message(STATUS "Resolving Boost library: ${lib}")

        # Init submodule
        boost_lib_checkout_submo("${install_dir}" libs/${lib})

        # Invoke b2

    endforeach()

    # b2 headers

endfunction(boost_lib_installer)