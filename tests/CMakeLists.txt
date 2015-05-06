cmake_minimum_required(VERSION 2.8)

message(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/)
SET(CMAKE_MODULE_PATH  ${CMAKE_CURRENT_SOURCE_DIR}/../cmake/)
include(BoostLib)

if(CMAKE_CL_64 EQUAL 0)
    SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /SAFESEH:NO")
endif()

require_boost_libs(1.58.0 "coroutine;optional")

include_directories(${Boost_INCLUDE_DIRS})
file(GLOB src "main.cpp")
add_executable(test-boost ${src})
target_link_libraries(test-boost ${Boost_LIBRARIES})