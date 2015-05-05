cmake_minimum_required(VERSION 2.8)

message(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/)
SET(CMAKE_MODULE_PATH  ${CMAKE_CURRENT_SOURCE_DIR}/../cmake/)
include(BoostLib)

require_boost_libs(1.58.0 "coroutine;optional")

include_directories(${Boost_INCLUDE_DIRS})
file(GLOB src "main.cpp")
add_executable(test-boost ${src})
target_link_libraries(test-boost ${Boost_LIBRARIES})