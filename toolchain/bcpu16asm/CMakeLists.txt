cmake_minimum_required(VERSION 3.1.0)

project(bcpu16asm)

add_subdirectory(../bcpu16lib b16lib_build)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

add_executable(bcpu16asm
    src/asmmain.cpp
)

target_link_libraries(bcpu16asm bcpu16lib)
