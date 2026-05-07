cmake_minimum_required(VERSION 3.14)
project(NumericalBenchmarks VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_BUILD_TYPE Release)
enable_testing()

add_library(numerical STATIC src/matrix_ops.cpp)
target_include_directories(numerical PUBLIC include)

add_executable(benchmark tests/benchmark_main.cpp)
target_link_libraries(benchmark numerical)

add_test(NAME MatrixMultiplication COMMAND benchmark)
