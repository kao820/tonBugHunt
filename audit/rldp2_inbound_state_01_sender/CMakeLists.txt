cmake_minimum_required(VERSION 3.16)
project(rldp2_inbound_state_01_sender CXX)

set(TON_SOURCE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." CACHE PATH "TON source root")
add_subdirectory("${TON_SOURCE_ROOT}" "${CMAKE_BINARY_DIR}/ton-root" EXCLUDE_FROM_ALL)

add_executable(rldp2_adnl_sender rldp2_adnl_sender.cpp)
target_include_directories(rldp2_adnl_sender PRIVATE "${TON_SOURCE_ROOT}")
target_link_libraries(rldp2_adnl_sender PRIVATE adnl tl_api tl-utils tdactor tdutils keys keyring)
