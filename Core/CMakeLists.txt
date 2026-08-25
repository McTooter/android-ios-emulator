cmake_minimum_required(VERSION 3.20)
project(AndroidRuntimeCore LANGUAGES CXX)

add_library(AndroidRuntimeCore STATIC EmulatorCore.cpp)
target_include_directories(AndroidRuntimeCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_features(AndroidRuntimeCore PUBLIC cxx_std_17)
target_compile_options(AndroidRuntimeCore PRIVATE
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:Release>:-ffunction-sections>
    $<$<CONFIG:Release>:-fdata-sections>
)

if(APPLE)
    target_compile_definitions(AndroidRuntimeCore PRIVATE EMULATOR_PLATFORM_APPLE=1)
endif()

add_executable(AndroidRuntimeCoreSmokeTest smoke_test.cpp)
target_link_libraries(AndroidRuntimeCoreSmokeTest PRIVATE AndroidRuntimeCore)
target_compile_features(AndroidRuntimeCoreSmokeTest PRIVATE cxx_std_17)
