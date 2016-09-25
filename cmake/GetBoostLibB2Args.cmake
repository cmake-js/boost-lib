cmake_minimum_required(VERSION 3.2)

function(get_boots_lib_b2_args)
    if(MSVC)
        if(CMAKE_CL_64 EQUAL 1)
            set(stage_dir stage64)
        else()
            set(stage_dir stage32)
        endif()
    else()
        set(stage_dir stage)
    endif()
        
    set(b2Args link=static
               threading=multi
               runtime-link=shared
               --build-dir=Build
               stage
               --stagedir=${stage_dir}
               -d+2
               --hash
               --ignore-site-config)
               
    message(STATUS "Generating b2 args.")
    
    if(NOT MSVC)
        if((CMAKE_BUILD_TYPE STREQUAL "Debug") OR (CMAKE_BUILD_TYPE STREQUAL "") OR (NOT DEFINED CMAKE_BUILD_TYPE))
            message(STATUS "\tvariant=debug")
            list(APPEND b2Args "variant=debug")
        else()
            message(STATUS "\tvariant=release")
            list(APPEND b2Args "variant=release")
        endif()
    endif(NOT MSVC)

    if(CMAKE_BUILD_TYPE STREQUAL "ReleaseNoInline")
        list(APPEND b2Args "cxxflags=${RELEASENOINLINE_FLAGS}")
    endif()
    if(CMAKE_BUILD_TYPE STREQUAL "DebugLibStdcxx")
        list(APPEND b2Args define=_GLIBCXX_DEBUG)
    endif()

    # Set up platform-specific b2 (bjam) command line arguments
    if(MSVC)
        if(MSVC11)
            list(APPEND b2Args toolset=msvc-11.0)
        elseif(MSVC12)
            list(APPEND b2Args toolset=msvc-12.0)
        elseif(MSVC14)
            list(APPEND b2Args toolset=msvc-14.0)
        endif()
        
        list(APPEND b2Args
                    define=_BIND_TO_CURRENT_MFC_VERSION=1
                    define=_BIND_TO_CURRENT_CRT_VERSION=1
                    --layout=versioned)
                    
        if(CMAKE_CL_64 EQUAL 1)
            list(APPEND b2Args address-model=64)
        else()
            list(APPEND b2Args address-model=32)
        endif()      
    elseif(APPLE)
        list(APPEND b2Args toolset=clang cxxflags=-fPIC cxxflags=-std=c++11 cxxflags=-stdlib=libc++ cxxflags=-mmacosx-version-min=10.7
                         linkflags=-stdlib=libc++ architecture=combined address-model=32_64 --layout=tagged)
    elseif(UNIX)
        list(APPEND b2Args --layout=tagged -sNO_BZIP2=1)
        if(ANDROID_BUILD)
            configure_file("${CMAKE_SOURCE_DIR}/tools/android/user-config.jam.in" "${BoostSourceDir}/tools/build/src/user-config.jam")
            list(APPEND b2Args toolset=gcc-android target-os=linux)
        else()
            list(APPEND b2Args cxxflags=-fPIC cxxflags=-std=c++11)
            # Need to configure the toolset based on whatever version CMAKE_CXX_COMPILER is
            # string(REGEX MATCH "[0-9]+\\.[0-9]+(\\.[0-9]+)?" ToolsetVer "${CMAKE_CXX_COMPILER_VERSION}")
            if(CMAKE_CXX_COMPILER_ID MATCHES "^(Apple)?Clang$")
                # list(APPEND b2Args toolset=clang-${ToolsetVer})
                list(APPEND b2Args toolset=clang)
                if(HAVE_LIBC++)
                    list(APPEND b2Args cxxflags=-stdlib=libc++ linkflags=-stdlib=libc++)
                endif()
            elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
                # list(APPEND b2Args toolset=gcc-${ToolsetVer})
                list(APPEND b2Args toolset=gcc)
            endif()
        endif()
    endif()

    set(b2Args "${b2Args}" PARENT_SCOPE)
endfunction(get_boots_lib_b2_args)
