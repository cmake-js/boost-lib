function(get_boots_lib_b2_args)
    set(b2Args link=static
               threading=multi
               runtime-link=shared
               --build-dir=Build
               stage
               -d+2
               --hash
               PARENT_SCOPE)

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
                  --layout=versioned
                  )
      # TODO: this is not working, detect x64 properly! (from toolset ending)
      if(TargetArchitecture STREQUAL "x86_64")
        list(APPEND b2Args address-model=64)
      endif()
    elseif(APPLE)
      list(APPEND b2Args variant=release toolset=clang cxxflags=-fPIC cxxflags=-std=c++11 cxxflags=-stdlib=libc++
                         linkflags=-stdlib=libc++ architecture=combined address-model=32_64 --layout=tagged)
    elseif(UNIX)
      list(APPEND b2Args --layout=tagged -sNO_BZIP2=1)
      if(ANDROID_BUILD)
        configure_file("${CMAKE_SOURCE_DIR}/tools/android/user-config.jam.in" "${BoostSourceDir}/tools/build/src/user-config.jam")
        list(APPEND b2Args toolset=gcc-android target-os=linux)
      else()
        list(APPEND b2Args variant=release cxxflags=-fPIC cxxflags=-std=c++11)
        # Need to configure the toolset based on whatever version CMAKE_CXX_COMPILER is
        string(REGEX MATCH "[0-9]+\\.[0-9]+" ToolsetVer "${CMAKE_CXX_COMPILER_VERSION}")
        if(CMAKE_CXX_COMPILER_ID MATCHES "^(Apple)?Clang$")
          list(APPEND b2Args toolset=clang-${ToolsetVer})
          if(HAVE_LIBC++)
            list(APPEND b2Args cxxflags=-stdlib=libc++ linkflags=-stdlib=libc++)
          endif()
        elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
          list(APPEND b2Args toolset=gcc-${ToolsetVer})
        endif()
      endif()
    endif()
endfunction(get_boots_lib_b2_args)