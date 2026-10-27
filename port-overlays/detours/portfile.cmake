# Overlay of the upstream `detours` port. Upstream builds with
# `vcpkg_build_nmake`, which aborts on a non-Windows host, so this port
# compiles the same sources with CMake through the chainloaded toolchain
# file instead (`cmake/toolchain-linux-clangcl.cmake` for the
# x64-windows-clangcl triplet) and produces the same
# `lib/detours.lib` + `include/detours/detours.h` layout.
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/Detours
    REF 9764cebcb1a75940e68fa83d6730ffaf0f669401
    SHA512 30f689a7f7dd3d762f1194ad8d7e05517678b754d6c0db297220f946485a8c8ec8a07cf5f3f893aabcc5623f64c81ee358e2a1c3ba23ba1fbd5856f6b3dd9eb7
    HEAD_REF main
)

# Matches the upstream Detours.vcxproj library list. detours.cpp must stay a
# separate translation unit: it contains one definition of each public Detour*
# function per architecture, selected by the DETOURS_X64/X86/... macros that
# detours.h derives from _AMD64_/_X86_. disasm.cpp is compiled twice over: once
# directly (emitting the generic DetourCopyInstruction/CDetourDis) and again
# through each disol*.cpp shim, which redefines those names to the per-arch
# symbols before #including it.
set(DETOURS_SOURCES
    "${SOURCE_PATH}/src/detours.cpp"
    "${SOURCE_PATH}/src/disasm.cpp"
    "${SOURCE_PATH}/src/modules.cpp"
    "${SOURCE_PATH}/src/disolx86.cpp"
    "${SOURCE_PATH}/src/disolx64.cpp"
    "${SOURCE_PATH}/src/disolia64.cpp"
    "${SOURCE_PATH}/src/disolarm.cpp"
    "${SOURCE_PATH}/src/disolarm64.cpp"
    "${SOURCE_PATH}/src/image.cpp"
    "${SOURCE_PATH}/src/creatwth.cpp"
)

# creatwth.cpp #includes uimports.cpp and both headers #include "detours.h",
# so the port copies what the build needs into a staging directory: the
# extracted tree has no CMakeLists.txt at the root to add, and
# `file(GLOB)`/`add_subdirectory` over src/ would hand CMake the sample trees too.
set(DETOURS_STAGE "${CURRENT_BUILDTREES_DIR}/src-staged")
file(MAKE_DIRECTORY "${DETOURS_STAGE}/src")
file(COPY ${DETOURS_SOURCES} DESTINATION "${DETOURS_STAGE}/src")
file(COPY "${SOURCE_PATH}/src/detours.h" "${SOURCE_PATH}/src/detver.h" "${SOURCE_PATH}/src/uimports.cpp" DESTINATION "${DETOURS_STAGE}/src")
file(WRITE "${DETOURS_STAGE}/CMakeLists.txt" [==[
cmake_minimum_required(VERSION 3.20)
project(detours CXX)

add_library(detours STATIC
    src/detours.cpp
    src/disasm.cpp
    src/modules.cpp
    src/disolx86.cpp
    src/disolx64.cpp
    src/disolia64.cpp
    src/disolarm.cpp
    src/disolarm64.cpp
    src/image.cpp
    src/creatwth.cpp
)

# Kept identical to the upstream NMake build: /MT (static CRT), /Od, and the
# pre-Vista minimum that lets Detours use the older import-table handling.
target_compile_definitions(detours PRIVATE
    WIN32_LEAN_AND_MEAN
    _WIN32_WINNT=0x501
    DETOURS_VERSION=0x4c0c1
)

# detours.h derives DETOURS_X64/DETOURS_64BIT from _AMD64_, the MSVC-only
# spelling. clang-cl defines _M_X64/_M_AMD64 but not _AMD64_, so without this
# the whole x64 path stays off and the generic DetourCopyInstruction from
# disasm.cpp is never emitted (link error: undefined symbol DetourCopyInstruction).
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    target_compile_definitions(detours PRIVATE _AMD64_)
else()
    target_compile_definitions(detours PRIVATE _X86_)
endif()
target_compile_options(detours PRIVATE /W4 /Gy /Gm- /Zl /Od)
target_include_directories(detours PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")

install(TARGETS detours ARCHIVE DESTINATION lib)
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/detours.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/detver.h" DESTINATION include/detours)
]==])

vcpkg_cmake_configure(
    SOURCE_PATH "${DETOURS_STAGE}"
    OPTIONS
        -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded
)

vcpkg_cmake_install()
vcpkg_copy_pdbs()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
