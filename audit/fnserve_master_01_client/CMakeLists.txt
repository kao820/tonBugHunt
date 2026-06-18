cmake_minimum_required(VERSION 3.16)
project(fnserve_master_01_client CXX)

set(TON_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." CACHE PATH "Path to TON repository root")
add_subdirectory("${TON_REPO_ROOT}" "${CMAKE_BINARY_DIR}/ton" EXCLUDE_FROM_ALL)

add_executable(fnserve_master_query_client fnserve_master_query_client.cpp)
target_include_directories(fnserve_master_query_client PRIVATE "${TON_REPO_ROOT}")
target_link_libraries(fnserve_master_query_client PRIVATE tdactor adnllite tl_api tl-lite-utils ton_crypto git)
