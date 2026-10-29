#!/bin/sh
set -eu

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' 0

cat > "$work_dir/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.16)
project(neat_sdk_link_check LANGUAGES CXX)
find_package(SimaNeat REQUIRED)
add_executable(neat_sdk_link_check main.cpp)
# Retain Neat so the linker validates its transitive runtime dependencies.
target_link_options(neat_sdk_link_check PRIVATE "LINKER:--no-as-needed")
target_link_libraries(neat_sdk_link_check PRIVATE SimaNeat::sima_neat)
CMAKE
printf '%s\n' 'int main() { return 0; }' > "$work_dir/main.cpp"

cmake -S "$work_dir" -B "$work_dir/build"
cmake --build "$work_dir/build" --parallel 1
