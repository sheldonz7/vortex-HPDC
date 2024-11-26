cmake_minimum_required(VERSION 3.10)
project(rtlsim)

# Find the YAML-cpp library
find_package(YamlCpp REQUIRED)

# Add the source files
file(GLOB SOURCES *.cpp)

# Add the library
add_library(rtlsim SHARED ${SOURCES})

# Link the YAML-cpp library
target_link_libraries(rtlsim YamlCpp::YamlCpp)
