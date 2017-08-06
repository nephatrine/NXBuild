# -------------------------------
# Copyright © 2017 Daniel Wolf <<nephatrine@gmail.com>>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
# -------------------------------

set(NXBUILD ON)

if("${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION}" LESS 3.3)
   message(FATAL_ERROR "CMake >= 3.3 required")
endif()

cmake_policy(PUSH)
cmake_policy(VERSION 3.3)
if(POLICY CMP0069)
	cmake_policy(SET CMP0069 NEW)
endif()

get_property(NX_CMAKE_ENABLED_LANGUAGES GLOBAL PROPERTY ENABLED_LANGUAGES)
get_filename_component(NX_BUILD_DIR ${CMAKE_BINARY_DIR} NAME)
string(REGEX REPLACE "^build-" "" NX_BUILD_DIR ${NX_BUILD_DIR})

if(DEFINED NX_CMAKE_CONTAINER_PROJECT AND NX_CMAKE_CONTAINER_PROJECT)
  set(NX_CMAKE_INSTALL_PACKAGE ON)
elseif(CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
  set(NX_CMAKE_INSTALL_PACKAGE ON)
else()
  set(NX_CMAKE_INSTALL_PACKAGE OFF)
endif()

# -------------------------------
# Keep MinGW & MSVC/GCC Packages Separate
#
# This allows us to have both MSVC and MinGW packages installing on the same
# system using the same install paths without CMake pulling in the config
# modules for the wrong compiler. (i.e. won't link msvc exe with mingw dlls)
#

if(MINGW)
  set(NXP "Mgw")
  set(NXPFind "Mgw")
endif()
macro(nx_find_package nxFindPackage)
	find_package(${nxFindPackage}${NXPFind} ${ARGN})
endmacro()

# -------------------------------
# Keep Debug & Release Packages Separate
#
# If we install both debug and release packages, we want CMake to always pull
# in the release build when using find_package unless the user specifies they
# want a debug version by appending "Debug" to the name in nx_find_package.
#
# Won't work with MSVC because multi-configuration projects are second-class
# citizens in CMake-land.
#

if("x${CMAKE_BUILD_TYPE}" STREQUAL "xDebug")
	set(NXP "Debug${NXP}")
endif()

# -------------------------------
# Code Generation Options
#

include(CMakeDependentOption)
include(CheckIPOSupport OPTIONAL
	RESULT_VARIABLE NX_CMAKE_CHECKIPOSUPPORT)

if(NX_CMAKE_CHECKIPOSUPPORT MATCHES "NOTFOUND")
	set(NX_HAS_IPO_SUPPORT ON)
else()
	check_ipo_support(RESULT NX_HAS_IPO_SUPPORT)
endif()

cmake_dependent_option(NX_CONFIG_USE_IPO "Enables Interprocedural Optimizations" ON NX_HAS_IPO_SUPPORT OFF)
cmake_dependent_option(NX_MSVC_DLL_RUNTIME "Enables /MD MSVC Option" ON MSVC OFF)
cmake_dependent_option(NX_MSVC_SECURE_WARNINGS "Disables _XXX_SECURE_NO_WARNINGS Macros" OFF MSVC OFF)

option(NX_CONFIG_USE_PIC "Enables Position Independent Code" ON)

set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ${NX_CONFIG_USE_IPO})
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_DEBUG OFF)
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ${NX_CONFIG_USE_IPO})

set(CMAKE_POSITION_INDEPENDENT_CODE ${NX_CONFIG_USE_PIC})

set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

if(MSVC)
	if(NOT NX_MSVC_SECURE_WARNINGS)
		add_definitions(-D_CRT_SECURE_NO_WARNINGS)
		add_definitions(-D_SCL_SECURE_NO_WARNINGS)
	endif()
	foreach(NX_CMAKE_FLAGS CMAKE_C_FLAGS CMAKE_CXX_FLAGS
			CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_DEBUG
			CMAKE_C_FLAGS_RELEASE CMAKE_CXX_FLAGS_RELEASE
			CMAKE_C_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_MINSIZEREL
			CMAKE_C_FLAGS_RELWITHDEBINFO CMAKE_CXX_FLAGS_RELWITHDEBINFO)
		if(DEFINED ${NX_CMAKE_FLAGS})
			string(REGEX REPLACE "/W3" "/W4" ${NX_CMAKE_FLAGS} ${${NX_CMAKE_FLAGS}})
			if(NOT NX_MSVC_DLL_RUNTIME)
				string(REGEX REPLACE "/MDd" "/MTd" ${NX_CMAKE_FLAGS} "${${NX_CMAKE_FLAGS}}")
				string(REGEX REPLACE "/MD" "/MT" ${NX_CMAKE_FLAGS} "${${NX_CMAKE_FLAGS}}")
			else()
				string(REGEX REPLACE "/MTd" "/MDd" ${NX_CMAKE_FLAGS} "${${NX_CMAKE_FLAGS}}")
				string(REGEX REPLACE "/MT" "/MD" ${NX_CMAKE_FLAGS} "${${NX_CMAKE_FLAGS}}")
			endif()
		endif()
	endforeach()
endif()

# -------------------------------
# Installation Options
#

include(GNUInstallDirs)

if(NOT DEFINED CMAKE_DEBUG_POSTFIX)
	set(CMAKE_DEBUG_POSTFIX -dev)
endif()

set(CMAKE_SKIP_BUILD_RPATH FALSE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)

set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
file(RELATIVE_PATH nxRPathRelative "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}" "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")
set(CMAKE_INSTALL_RPATH "$ORIGIN/${nxRPathRelative}:$ORIGIN/")

# -------------------------------
# Packaging Options
#

if(NX_CMAKE_INSTALL_PACKAGE)
	find_package(NSIS QUIET)
	find_package(DPKG QUIET)
	find_package(RPM QUIET)
	cmake_dependent_option(NX_INSTALLER_USE_NSIS "Create NSIS EXE Installer" ${NSIS_FOUND} WIN32 OFF)
	cmake_dependent_option(NX_INSTALLER_USE_DEB "Create Debian DEB Installer" ${DPKG_FOUND} "UNIX;NOT APPLE" OFF)
	cmake_dependent_option(NX_INSTALLER_USE_RPM "Create Red Hat RPM Installer" ${RPM_FOUND} "UNIX;NOT APPLE" OFF)
	cmake_dependent_option(NX_PACKAGE_USE_7Z "Create 7-ZIP Archives" ON WIN32 OFF)
	cmake_dependent_option(NX_PACKAGE_USE_ZIP "Create ZIP Archives" OFF WIN32 OFF)
	cmake_dependent_option(NX_PACKAGE_USE_TGZ "Create GZip-Compressed TAR Archives" OFF UNIX OFF)
	cmake_dependent_option(NX_PACKAGE_USE_TXZ "Create LZMA-Compressed TAR Archives" ON UNIX OFF)
endif()

set(CPACK_COMPONENT_GROUP_BIN_DISPLAY_NAME "End-User")
set(CPACK_COMPONENT_BINARY_DISPLAY_NAME "Executable(s)")
set(CPACK_COMPONENT_BINARY_GROUP bin)
set(CPACK_COMPONENT_SHARED_DISPLAY_NAME "Shared Library")
set(CPACK_COMPONENT_SHARED_GROUP bin)
set(CPACK_COMPONENT_SYSTEM_DISPLAY_NAME "Dependencies")
set(CPACK_COMPONENT_SYSTEM_GROUP bin)

set(CPACK_COMPONENT_GROUP_DEV_DISPLAY_NAME "Developer")
set(CPACK_COMPONENT_EXPORT_DISPLAY_NAME "CMake Package")
set(CPACK_COMPONENT_EXPORT_GROUP dev)
set(CPACK_COMPONENT_HEADERS_DISPLAY_NAME "Header Files")
set(CPACK_COMPONENT_HEADERS_GROUP dev)
set(CPACK_COMPONENT_INTLIB_DISPLAY_NAME "Source Library")
set(CPACK_COMPONENT_INTLIB_GROUP dev)
set(CPACK_COMPONENT_STATIC_DISPLAY_NAME "Static Library")
set(CPACK_COMPONENT_STATIC_GROUP dev)

set(CPACK_COMPONENT_GROUP_DOC_DISPLAY_NAME "Documentation")
set(CPACK_COMPONENT_APIREF_DISPLAY_NAME "API Reference")
set(CPACK_COMPONENT_APIREF_GROUP doc)
set(CPACK_COMPONENT_README_DISPLAY_NAME "Documentation")
set(CPACK_COMPONENT_README_GROUP doc)
set(CPACK_COMPONENT_LICENSE_DISPLAY_NAME "License")
set(CPACK_COMPONENT_LICENSE_GROUP doc)

# -------------------------------
# Tooling Options
#

find_package(ClangFormat QUIET)
find_package(ClangTidy QUIET)
find_package(IWYU QUIET)

cmake_dependent_option(NX_TOOL_USE_CLANG_TIDY "Enables clang-tidy Checks" ON "CLANG_TIDY_FOUND;NX_CLANG" OFF)
cmake_dependent_option(NX_TOOL_USE_IWYU "Enables include-what-you-use Checks" ON "IWYU_FOUND;NX_CLANG" OFF)
cmake_dependent_option(NX_CMAKE_USE_TESTS "Enable Test Cases" ON "NOT CMAKE_TOOLCHAIN_FILE" OFF)

option(NX_CMAKE_EXPORT_BUILD "Export CMake Config For Build Directory" ON)

if(CMAKE_C_COMPILER_ID MATCHES "Clang" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
	set(NX_CLANG ON)
endif()

if(NX_TOOL_USE_CLANG_TIDY)
	if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.clang-tidy")
		file(COPY "${CMAKE_CURRENT_SOURCE_DIR}/.clang-tidy" DESTINATION "${CMAKE_CURRENT_BINARY_DIR}")
	endif()
	set(CMAKE_C_CLANG_TIDY "${CLANG_TIDY_EXECUTABLE}")
	set(CMAKE_CXX_CLANG_TIDY "${CLANG_TIDY_EXECUTABLE}")
endif()

if(NX_TOOL_USE_IWYU)
	set(CMAKE_C_INCLUDE_WHAT_YOU_USE "${IWYU_EXECUTABLE}")
	set(CMAKE_CXX_INCLUDE_WHAT_YOU_USE "${IWYU_EXECUTABLE}")
endif()

if(NX_CMAKE_USE_TESTS)
	enable_testing()
endif()

# -------------------------------
# Helper Functions
# Can be called by end-user but are primarily there to support other functions.
#

if("C" IN_LIST NX_CMAKE_ENABLED_LANGUAGES)
	include(CheckCCompilerFlag)
	include(CheckCSourceCompiles)
endif()

if("CXX" IN_LIST NX_CMAKE_ENABLED_LANGUAGES)
	include(CheckCXXCompilerFlag)
	include(CheckCXXSourceCompiles)
endif()

function(nx_check_compile_options nxParentVariable)
	foreach(nxCFlagArg ${ARGN})
		if("C" IN_LIST NX_CMAKE_ENABLED_LANGUAGES)
			string(TOUPPER "HAS_CFLAG${nxCFlagArg}" nxCFlagCheck)
			string(MAKE_C_IDENTIFIER ${nxCFlagCheck} nxCFlagCheck)
			check_c_compiler_flag(${nxCFlagArg} ${nxCFlagCheck})
			if(${nxCFlagCheck})
				list(APPEND nxCFlagSupport $<$<COMPILE_LANGUAGE:C>:${nxCFlagArg}>)
				list(APPEND nxCFlagSupport_RAW ${nxCFlagArg})
			endif()
		endif()
		if("CXX" IN_LIST NX_CMAKE_ENABLED_LANGUAGES)
			string(TOUPPER "HAS_CXXFLAG${nxCFlagArg}" nxCFlagCheck)
			string(MAKE_C_IDENTIFIER ${nxCFlagCheck} nxCFlagCheck)
			check_cxx_compiler_flag(${nxCFlagArg} ${nxCFlagCheck})
			if(${nxCFlagCheck})
				list(APPEND nxCFlagSupport $<$<COMPILE_LANGUAGE:CXX>:${nxCFlagArg}>)
				list(APPEND nxCFlagSupport_RAW ${nxCFlagArg})
			endif()
		endif()
	endforeach()
	if(DEFINED nxCFlagSupport_RAW)
		list(REMOVE_DUPLICATES nxCFlagSupport_RAW)
	endif()
	if(MSVC)
		set(nxCFlagSupport ${nxCFlagSupport_RAW})
	endif()
	set(${nxParentVariable}_RAW ${${nxParentVariable}_RAW} ${nxCFlagSupport_RAW}
		PARENT_SCOPE)
	set(${nxParentVariable} ${${nxParentVariable}} ${nxCFlagSupport}
		PARENT_SCOPE)
endfunction()

function(nx_check_linker_flags nxParentVariable)
	set(nxLDFlagOriginal ${CMAKE_EXE_LINKER_FLAGS})
	foreach(nxLDFlagArg ${ARGN})
		set(CMAKE_EXE_LINKER_FLAGS "${nxLDFlagOriginal} ${nxLDFlagArg}")
		string(TOUPPER "HAS_LINK${nxLDFlagArg}" nxLDFlagCheck)
		string(MAKE_C_IDENTIFIER ${nxLDFlagCheck} nxLDFlagCheck)
		if("CXX" IN_LIST NX_CMAKE_ENABLED_LANGUAGES)
			check_cxx_source_compiles("int main(int argc, char *argv[]) {return 0;}" ${nxLDFlagCheck})
		elseif("C" IN_LIST NX_CMAKE_ENABLED_LANGUAGES)
			check_c_source_compiles("int main(int argc, char *argv[]) {return 0;}" ${nxLDFlagCheck})
		endif()
		if(${nxLDFlagCheck})
			list(APPEND nxLDFlagSupport ${nxLDFlagArg})
		endif()
	endforeach()
	set(CMAKE_EXE_LINKER_FLAGS ${nxLDFlagOriginal})
	set(${nxParentVariable} ${${nxParentVariable}} ${nxLDFlagSupport}
		PARENT_SCOPE)
endfunction()

function(nx_documentation)
	set(nxDocumentMode DOCUMENTS)
	foreach(nxDocumentArg ${ARGN})
		if("x${nxDocumentArg}" STREQUAL "xDOCUMENTS")
			set(nxDocumentMode DOCUMENTS)
		elseif("x${nxDocumentArg}" STREQUAL "xCOPYRIGHT")
			set(nxDocumentMode COPYRIGHT)
		elseif("x${nxDocumentArg}" STREQUAL "xREFERENCE")
			set(nxDocumentMode REFERENCE)
		else()
			get_filename_component(nxDocumentArg "${nxDocumentArg}" ABSOLUTE)
			if(IS_DIRECTORY "${nxDocumentArg}")
				list(APPEND ${nxDocumentMode}_DIRECTORIES "${nxDocumentArg}")
			else()
				list(APPEND ${nxDocumentMode}_TARGETS "${nxDocumentArg}")
			endif()
		endif()
	endforeach()
	foreach(nxDocumentPath ${COPYRIGHT_DIRECTORIES})
		install(DIRECTORY "${nxDocumentPath}/"
			DESTINATION "${CMAKE_INSTALL_DOCDIR}-${PROJECT_VERSION}"
			COMPONENT license)
	endforeach()
	if(COPYRIGHT_TARGETS)
		install(FILES ${COPYRIGHT_TARGETS}
			DESTINATION "${CMAKE_INSTALL_DOCDIR}-${PROJECT_VERSION}"
			COMPONENT license)
		list(GET COPYRIGHT_TARGETS 0 CPACK_RESOURCE_FILE_LICENSE)
		list(APPEND CPACK_COMPONENT_EXPORT_DEPENDS license)
		list(APPEND CPACK_COMPONENT_INTLIB_DEPENDS license)
		list(APPEND CPACK_COMPONENT_STATIC_DEPENDS license)
		list(APPEND CPACK_COMPONENT_SHARED_DEPENDS license)
		list(APPEND CPACK_COMPONENT_BINARY_DEPENDS license)
		list(APPEND CPACK_COMPONENT_HEADERS_DEPENDS license)
		set(CPACK_RESOURCE_FILE_LICENSE ${CPACK_RESOURCE_FILE_LICENSE}
			PARENT_SCOPE)
		set(CPACK_COMPONENT_EXPORT_DEPENDS ${CPACK_COMPONENT_EXPORT_DEPENDS}
			PARENT_SCOPE)
		set(CPACK_COMPONENT_INTLIB_DEPENDS ${CPACK_COMPONENT_INTLIB_DEPENDS}
			PARENT_SCOPE)
		set(CPACK_COMPONENT_STATIC_DEPENDS ${CPACK_COMPONENT_STATIC_DEPENDS}
			PARENT_SCOPE)
		set(CPACK_COMPONENT_SHARED_DEPENDS ${CPACK_COMPONENT_SHARED_DEPENDS}
			PARENT_SCOPE)
		set(CPACK_COMPONENT_BINARY_DEPENDS ${CPACK_COMPONENT_BINARY_DEPENDS}
			PARENT_SCOPE)
		set(CPACK_COMPONENT_HEADERS_DEPENDS ${CPACK_COMPONENT_HEADERS_DEPENDS}
			PARENT_SCOPE)
	endif()
	if(NX_CMAKE_INSTALL_PACKAGE)
		foreach(nxDocumentPath ${DOCUMENTS_DIRECTORIES})
			install(DIRECTORY "${nxDocumentPath}/"
				DESTINATION "${CMAKE_INSTALL_DOCDIR}-${PROJECT_VERSION}"
				COMPONENT readme)
		endforeach()
	endif()
	if(DOCUMENTS_TARGETS)
		if(NX_CMAKE_INSTALL_PACKAGE)
			install(FILES ${DOCUMENTS_TARGETS}
				DESTINATION "${CMAKE_INSTALL_DOCDIR}-${PROJECT_VERSION}"
				COMPONENT readme)
		endif()
		list(GET DOCUMENTS_TARGETS 0 CPACK_PACKAGE_DESCRIPTION_FILE)
		list(GET DOCUMENTS_TARGETS 0 CPACK_RESOURCE_FILE_README)
		set(CPACK_PACKAGE_DESCRIPTION_FILE ${CPACK_PACKAGE_DESCRIPTION_FILE}
			PARENT_SCOPE)
		set(CPACK_RESOURCE_FILE_README ${CPACK_RESOURCE_FILE_README}
			PARENT_SCOPE)
	endif()
	if(NX_CMAKE_INSTALL_PACKAGE)
		foreach(nxDocumentPath ${REFERENCE_DIRECTORIES})
			install(DIRECTORY "${nxDocumentPath}/"
				DESTINATION "${CMAKE_INSTALL_DOCDIR}-${PROJECT_VERSION}"
				COMPONENT apiref)
		endforeach()
	endif()
	if(REFERENCE_TARGETS)
		if(NX_CMAKE_INSTALL_PACKAGE)
			install(FILES ${REFERENCE_TARGETS}
				DESTINATION "${CMAKE_INSTALL_DOCDIR}-${PROJECT_VERSION}"
				COMPONENT apiref)
		endif()
	endif()
endfunction()

function(nx_install_system_runtime)
	set(CMAKE_INSTALL_SYSTEM_RUNTIME_COMPONENT system)
	if(NX_CMAKE_INSTALL_PACKAGE)
		include(InstallRequiredSystemLibraries)
	endif()
endfunction()

function(nx_target_compile_definitions)
	set(nxDefineMode TARGET)
	set(nxDefineForce OFF)
	foreach(nxDefineArg ${ARGN})
		if("x${nxDefineArg}" STREQUAL "xTARGET")
			set(nxDefineMode TARGET)
		elseif("x${nxDefineArg}" STREQUAL "xPUBLIC")
			if(NOT nxDefineForce)
				set(nxDefineMode PUBLIC)
			endif()
		elseif("x${nxDefineArg}" STREQUAL "xPRIVATE")
			if(NOT nxDefineForce)
				set(nxDefineMode PRIVATE)
			endif()
		elseif("x${nxDefineArg}" STREQUAL "xINTERFACE")
			set(nxDefineMode INTERFACE)
		elseif("x${nxDefineArg}" STREQUAL "xFORCE_INTERFACE")
			set(nxDefineMode INTERFACE)
			set(nxDefineForce ON)
		elseif("x${nxDefineMode}" STREQUAL "xTARGET")
			list(APPEND nxDefineTargets ${nxDefineArg})
		else()
			list(APPEND ${nxDefineMode}_DEFINITIONS ${nxDefineArg})
		endif()
	endforeach()
	foreach(nxDefineTarget ${nxDefineTargets})
		foreach(nxDefineMode PRIVATE PUBLIC INTERFACE)
			if(DEFINED ${nxDefineMode}_DEFINITIONS)
				target_compile_definitions(${nxDefineTarget} ${nxDefineMode} ${${nxDefineMode}_DEFINITIONS})
			endif()
		endforeach()
	endforeach()
endfunction()

function(nx_target_compile_options)
	set(nxCFlagMode TARGET)
	set(nxCFlagForce OFF)
	foreach(nxCFlagArg ${ARGN})
		if("x${nxCFlagArg}" STREQUAL "xTARGET")
			set(nxCFlagMode TARGET)
		elseif("x${nxCFlagArg}" STREQUAL "xPUBLIC")
			if(NOT nxCFlagForce)
				set(nxCFlagMode PUBLIC)
			endif()
		elseif("x${nxCFlagArg}" STREQUAL "xPRIVATE")
			if(NOT nxCFlagForce)
				set(nxCFlagMode PRIVATE)
			endif()
		elseif("x${nxCFlagArg}" STREQUAL "xINTERFACE")
			set(nxCFlagMode INTERFACE)
		elseif("x${nxCFlagArg}" STREQUAL "xFORCE_INTERFACE")
			set(nxCFlagMode INTERFACE)
			set(nxCFlagForce ON)
		elseif("x${nxCFlagMode}" STREQUAL "xTARGET")
			list(APPEND nxCFlagTargets ${nxCFlagArg})
		else()
			list(APPEND ${nxCFlagMode}_OPTIONS ${nxCFlagArg})
		endif()
	endforeach()
	foreach(nxCFlagTarget ${nxCFlagTargets})
		foreach(nxCFlagMode PRIVATE PUBLIC INTERFACE)
			if(DEFINED ${nxCFlagMode}_OPTIONS)
				target_compile_options(${nxCFlagTarget} ${nxCFlagMode} ${${nxCFlagMode}_OPTIONS})
			endif()
		endforeach()
	endforeach()
endfunction()

function(nx_target_include_directories)
	set(nxIncludeInstall "${PROJECT_NAME}-${PROJECT_VERSION}")
	set(nxIncludeMode TARGET)
	set(nxIncludeForce OFF)
	foreach(nxIncludeArg ${ARGN})
		if("x${nxIncludeArg}" STREQUAL "xTARGET")
			set(nxIncludeMode TARGET)
		elseif("x${nxIncludeArg}" STREQUAL "xPUBLIC")
			if(NOT nxIncludeForce)
				set(nxIncludeMode PUBLIC)
			endif()
		elseif("x${nxIncludeArg}" STREQUAL "xPRIVATE")
			if(NOT nxIncludeForce)
				set(nxIncludeMode PRIVATE)
			endif()
		elseif("x${nxIncludeArg}" STREQUAL "xINTERFACE")
			set(nxIncludeMode INTERFACE)
		elseif("x${nxIncludeArg}" STREQUAL "xFORCE_INTERFACE")
			set(nxIncludeMode INTERFACE)
			set(nxIncludeForce ON)
		elseif("x${nxIncludeArg}" STREQUAL "xINSTALL")
			set(nxIncludeMode INSTALL)
		elseif("x${nxIncludeMode}" STREQUAL "xINSTALL")
			set(nxIncludeInstall "${nxIncludeArg}")
		elseif("x${nxIncludeMode}" STREQUAL "xTARGET")
			list(APPEND nxIncludeTargets ${nxIncludeArg})
		else()
			get_filename_component(nxIncludeArg "${nxIncludeArg}" ABSOLUTE)
			file(RELATIVE_PATH nxIncludePathSource "${CMAKE_CURRENT_SOURCE_DIR}" "${nxIncludeArg}")
			file(RELATIVE_PATH nxIncludePathBuild "${CMAKE_CURRENT_BINARY_DIR}" "${nxIncludeArg}")
			string(SUBSTRING "${nxIncludePathSource}" 0 2 nxIncludePrefixSource)
			string(SUBSTRING "${nxIncludePathBuild}" 0 2 nxIncludePrefixBuild)
			if("x${nxIncludePrefixBuild}" STREQUAL "x..")
				if("x${nxIncludePrefixSource}" STREQUAL "x..")
					list(APPEND ${nxIncludeMode}_DIRECTORIES_EXTERNAL "${nxIncludeArg}")
				else()
					list(APPEND ${nxIncludeMode}_DIRECTORIES "${nxIncludePathSource}")
					list(APPEND ${nxIncludeMode}_DIRECTORIES_BUILD "${nxIncludePathSource}")
				endif()
			else()
				list(APPEND ${nxIncludeMode}_DIRECTORIES_BUILD "${nxIncludePathBuild}")
			endif()
		endif()
	endforeach()
	foreach(nxIncludeTarget ${nxIncludeTargets})
		foreach(nxIncludeMode PRIVATE PUBLIC INTERFACE)
			if(DEFINED ${nxIncludeMode}_DIRECTORIES_EXTERNAL)
				target_include_directories(${nxIncludeTarget} ${nxIncludeMode} "${${nxIncludeMode}_DIRECTORIES_EXTERNAL}")
			endif()
		endforeach()
		foreach(nxIncludePath ${PRIVATE_DIRECTORIES_BUILD})
			file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${nxIncludePath}")
			target_include_directories(${nxIncludeTarget} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${nxIncludePath}")
		endforeach()
		foreach(nxIncludeMode PUBLIC INTERFACE)
			foreach(nxIncludePath ${${nxIncludeMode}_DIRECTORIES_BUILD})
				file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${nxIncludePath}")
				target_include_directories(${nxIncludeTarget} ${nxIncludeMode} $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/${nxIncludePath}>)
			endforeach()
		endforeach()
		foreach(nxIncludePath ${PRIVATE_DIRECTORIES})
			target_include_directories(${nxIncludeTarget} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/${nxIncludePath}")
		endforeach()
		foreach(nxIncludeMode PUBLIC INTERFACE)
			foreach(nxIncludePath ${${nxIncludeMode}_DIRECTORIES})
				target_include_directories(${nxIncludeTarget} ${nxIncludeMode} $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${nxIncludePath}>)
			endforeach()
		endforeach()
		target_include_directories(${nxIncludeTarget} INTERFACE $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${nxIncludeInstall}>)
		target_include_directories(${nxIncludeTarget} INTERFACE $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${nxIncludeInstall}/${NX_BUILD_DIR}>)
	endforeach()
	if(NX_CMAKE_INSTALL_PACKAGE)
		foreach(nxIncludePath ${PUBLIC_DIRECTORIES} ${INTERFACE_DIRECTORIES})
			install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${nxIncludePath}/"
				DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${nxIncludeInstall}"
				COMPONENT headers)
		endforeach()
		foreach(nxIncludePath ${PUBLIC_DIRECTORIES_BUILD} ${INTERFACE_DIRECTORIES_BUILD})
			install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${nxIncludePath}/"
				DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${nxIncludeInstall}/${NX_BUILD_DIR}"
				COMPONENT headers)
		endforeach()
	endif()
endfunction()

function(nx_target_link_flags)
	set(nxLDFlagMode TARGET)
	foreach(nxLDFlagArg ${ARGN})
		if("x${nxLDFlagArg}" STREQUAL "xTARGET")
			set(nxLDFlagMode TARGET)
		elseif("x${nxLDFlagArg}" STREQUAL "xPUBLIC")
			message(WARNING "PUBLIC LINK_FLAGS NOT IMPLEMENTED")
			set(nxLDFlagMode PRIVATE)
		elseif("x${nxLDFlagArg}" STREQUAL "xPRIVATE")
			set(nxLDFlagMode PRIVATE)
		elseif("x${nxLDFlagArg}" STREQUAL "xINTERFACE")
			message(WARNING "INTERFACE LINK_FLAGS NOT IMPLEMENTED")
			set(nxLDFlagMode INTERFACE)
		elseif("x${nxLDFlagMode}" STREQUAL "xTARGET")
			list(APPEND nxLDFlagTargets ${nxLDFlagArg})
		else()
			set(${nxLDFlagMode}_FLAGS "${${nxLDFlagMode}_FLAGS} ${nxLDFlagArg}")
		endif()
	endforeach()
	if(DEFINED PRIVATE_FLAGS)
		foreach(nxLDFlagTarget ${nxLDFlagTargets})
			get_target_property(nxLDFlagPrevious ${nxLDFlagTarget} LINK_FLAGS)
			if(nxLDFlagPrevious MATCHES "NOTFOUND")
				set_target_properties(${nxLDFlagTarget} PROPERTIES
					LINK_FLAGS "${PRIVATE_FLAGS}")
			else()
				set_target_properties(${nxLDFlagTarget} PROPERTIES
					LINK_FLAGS "${nxLDFlagPrevious} ${PRIVATE_FLAGS}")
			endif()
		endforeach()
	endif()
endfunction()

function(nx_target_link_libraries)
	set(nxLibraryMode TARGET)
	set(nxLibraryForce OFF)
	foreach(nxLibraryArg ${ARGN})
		if("x${nxLibraryArg}" STREQUAL "xTARGET")
			set(nxLibraryMode TARGET)
		elseif("x${nxLibraryArg}" STREQUAL "xPUBLIC")
			if(NOT nxLibraryForce)
				set(nxLibraryMode PUBLIC)
			endif()
		elseif("x${nxLibraryArg}" STREQUAL "xPRIVATE")
			if(NOT nxLibraryForce)
				set(nxLibraryMode PRIVATE)
			endif()
		elseif("x${nxLibraryArg}" STREQUAL "xINTERFACE")
			set(nxLibraryMode INTERFACE)
		elseif("x${nxLibraryArg}" STREQUAL "xFORCE_INTERFACE")
			set(nxLibraryMode INTERFACE)
			set(nxLibraryForce ON)
		elseif("x${nxLibraryMode}" STREQUAL "xTARGET")
			list(APPEND nxLibraryTargets ${nxLibraryArg})
		else()
			list(APPEND ${nxLibraryMode}_LIBRARIES ${nxLibraryArg})
		endif()
	endforeach()
	foreach(nxLibraryTarget ${nxLibraryTargets})
		foreach(nxLibraryMode PRIVATE PUBLIC INTERFACE)
			if(DEFINED ${nxLibraryMode}_LIBRARIES)
				target_link_libraries(${nxLibraryTarget} ${nxLibraryMode} ${${nxLibraryMode}_LIBRARIES})
			endif()
		endforeach()
	endforeach()
endfunction()

# -------------------------------
# nx_config
#

function(nx_config)
	set(nxConfigMode NONE)
	set(nxConfigSecure OFF)
	foreach(nxConfigArg ${ARGN})
		if("x${nxConfigArg}" STREQUAL "xC")
			set(nxConfigLanguage C)
		elseif("x${nxConfigArg}" STREQUAL "xCXX")
			set(nxConfigLanguage CXX)
		elseif("x${nxConfigArg}" STREQUAL "xSECURE")
			set(nxConfigSecure ON)
		elseif("x${nxConfigArg}" STREQUAL "xCOMPILE_FLAGS")
			set(nxConfigMode COMPILE_FLAGS)
		elseif("x${nxConfigArg}" STREQUAL "xLINK_FLAGS")
			set(nxConfigMode LINK_FLAGS)
		elseif("x${nxConfigMode}" STREQUAL "xCOMPILE_FLAGS")
			nx_check_compile_options(retCompiler ${nxConfigArg})
		elseif("x${thisLink}" STREQUAL "xLINK_FLAGS")
			nx_check_linker_flags(retLinker ${nxConfigArg})
		elseif("x${nxConfigArg}" MATCHES "^x[0-9]+$")
			if(DEFINED nxConfigLanguage)
				set(CMAKE_${nxConfigLanguage}_STANDARD ${nxConfigArg}
					PARENT_SCOPE)
				set(CMAKE_${nxConfigLanguage}_STANDARD_REQUIRED ON
					PARENT_SCOPE)
			endif()
		endif()
	endforeach()
	if(MSVC)
		nx_check_compile_options(retCompiler -MP -bigobj -permissive-)
		if("x${CMAKE_BUILD_TYPE}" STREQUAL "x" OR "x${CMAKE_BUILD_TYPE}" STREQUAL "xRelease")
			if(NX_CONFIG_USE_IPO AND NX_CMAKE_CHECKIPOSUPPORT MATCHES "NOTFOUND")
				nx_check_compile_options(retCompilerLTO -GL)
				nx_check_linker_flags(retLinkerLTO -LTCG)
				set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} ${retCompilerLTO_RAW}")
				set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} ${retLinkerLTO_RAW}")
			endif()
		endif()
	else()
		nx_check_compile_options(retCompiler -Wall -Wextra -Wshadow -pedantic -pipe)
		nx_check_linker_flags(retLinker -Wl,-O1 -Wl,--as-needed -Wl,--discard-all -Wl,--hash-style=gnu -Wl,--no-copy-dt-needed-entries -Wl,--no-undefined)
		if(nxConfigSecure)
			add_definitions(-D_FORTIFY_SOURCE=2)
			nx_check_compile_options(retCompiler -Wformat=2 -fstack-protector-strong)
			nx_check_linker_flags(retLinker -Wl,-z,now -Wl,-z,relro)
			if(MSYS OR MINGW)
				nx_check_linker_flags(retLinker -Wl,--nxcompat -Wl,--dynamicbase -Wl,--high-entropy-va)
			endif()
		endif()
		if("x${CMAKE_BUILD_TYPE}" STREQUAL "x" OR "x${CMAKE_BUILD_TYPE}" STREQUAL "xRelease")
			if(NX_CONFIG_USE_IPO AND NX_CMAKE_CHECKIPOSUPPORT MATCHES "NOTFOUND")
				nx_check_compile_options(retCompilerSafe -flto -flto=full -ffat-lto-objects -flto-partition=1to1)
				nx_check_linker_flags(retLinkerLTO -fuse-linker-plugin)
				if(HAS_LINK_FUSE_LINKER_PLUGIN)
					nx_check_compile_options(retCompilerLTO -flto -flto=thin -fno-fat-lto-objects -flto-partition=1to1)
				else()
					nx_check_compile_options(retCompilerLTO ${retCompilerSafe})
					nx_check_compile_options(retCompilerLTO_RAW ${retCompilerSafe_RAW})
				endif()
			endif()
		endif()
		if(NX_CONFIG_USE_PIC)
			nx_check_compile_options(retCompilerPIE -fPIE)
			nx_check_linker_flags(retLinkerPIE -Wl,-pie -Wno-unused-command-line-argument -pie)
			if(MSYS OR MINGW)
				if(CMAKE_SIZEOF_VOID_P EQUAL 8)
					nx_check_linker_flags(retLinkerPIE -Wl,--pic-executable -Wl,-e,mainCRTStartup)
				elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
					nx_check_linker_flags(retLinkerPIE -Wl,--pic-executable -Wl,-e,_mainCRTStartup)
				endif()
			endif()
		endif()
		nx_check_linker_flags(retLinkerLTO ${retCompilerLTO_RAW})
		nx_check_linker_flags(retLinkerPIE ${retCompilerPIE_RAW})
		nx_check_linker_flags(retLinker ${retCompiler_RAW})
		set(NX_LTO_SAFE_COMPILER_FLAGS ${NX_LTO_SAFE_COMPILER_FLAGS} ${retCompilerSafe}
			PARENT_SCOPE)
		set(NX_LTO_COMPILER_FLAGS ${NX_LTO_COMPILER_FLAGS} ${retCompilerLTO}
			PARENT_SCOPE)
		set(NX_LTO_LINKER_FLAGS ${NX_LTO_LINKER_FLAGS} ${retLinkerLTO}
			PARENT_SCOPE)
		set(NX_PIE_COMPILER_FLAGS ${NX_PIE_COMPILER_FLAGS} ${retCompilerPIE}
			PARENT_SCOPE)
		set(NX_PIE_LINKER_FLAGS ${NX_PIE_LINKER_FLAGS} ${retLinkerPIE}
			PARENT_SCOPE)
	endif()
	
	set(NX_COMPILER_FLAGS ${NX_COMPILER_FLAGS} ${retCompiler}
		PARENT_SCOPE)
	set(NX_LINKER_FLAGS ${NX_LINKER_FLAGS} ${retLinker}
		PARENT_SCOPE)
endfunction()

# -------------------------------
# nx_target
#

include(CMakePackageConfigHelpers)
include(GenerateExportHeader)

function(nx_target nxParentVariable nxTargetName nxTargetType)
	set(nxTargetInstall ON)
	set(nxTargetMode SOURCE)
	foreach(nxTargetArg ${ARGN})
		if("x${nxTargetArg}" STREQUAL "xSOURCE")
			set(nxTargetMode SOURCE)
		elseif("x${nxTargetArg}" STREQUAL "xCOMPILE_FLAGS")
			set(nxTargetMode COMPILE_FLAGS)
		elseif("x${nxTargetArg}" STREQUAL "xDEFINE")
			set(nxTargetMode DEFINE)
		elseif("x${nxTargetArg}" STREQUAL "xEXPORT")
			set(nxTargetMode EXPORT)
		elseif("x${nxTargetArg}" STREQUAL "xINCLUDE")
			set(nxTargetMode INCLUDE)
		elseif("x${nxTargetArg}" STREQUAL "xLINK")
			set(nxTargetMode LINK)
		elseif("x${nxTargetArg}" STREQUAL "xBASE_DIR")
			set(nxTargetMode BASE_DIR)
		elseif("x${nxTargetArg}" STREQUAL "xGUI")
			if(WIN32 AND NOT "x${CMAKE_BUILD_TYPE}" STREQUAL "xDebug")
				set(nxGuiMode WIN32)
			endif()
		elseif("x${nxTargetArg}" STREQUAL "xLINK_FLAGS")
			set(nxTargetMode LINK_FLAGS)
		elseif("x${nxTargetArg}" STREQUAL "xAPIVERSION")
			set(nxTargetMode APIVERSION)
		elseif("x${nxTargetArg}" STREQUAL "xNO_INSTALL")
			set(nxTargetInstall OFF)
		elseif("x${nxTargetMode}" STREQUAL "xAPIVERSION")
			set(nxTargetVersion ${nxTargetArg})
			set(nxTargetPostfix "-${nxTargetVersion}")
		elseif("x${nxTargetMode}" STREQUAL "xBASE_DIR")
			set(nxTargetBase ${nxTargetArg})
		elseif("x${nxTargetMode}" STREQUAL "xEXPORT")
			set(nxTargetMode INCLUDE)
			set(nxTargetExport "${nxTargetArg}")
		elseif("x${nxTargetMode}" STREQUAL "xSOURCE")
			get_filename_component(nxTargetArg "${nxTargetArg}" ABSOLUTE)
			file(RELATIVE_PATH nxTargetPathSource "${CMAKE_CURRENT_SOURCE_DIR}" "${nxTargetArg}")
			file(RELATIVE_PATH nxTargetPathBuild "${CMAKE_CURRENT_BINARY_DIR}" "${nxTargetArg}")
			string(SUBSTRING "${nxTargetPathSource}" 0 2 nxTargetPrefixSource)
			string(SUBSTRING "${nxTargetPathBuild}" 0 2 nxTargetPrefixBuild)
			if("x${nxTargetPrefixBuild}" STREQUAL "x..")
				if("x${nxTargetPrefixSource}" STREQUAL "x..")
					list(APPEND SOURCE_AGGREGATE_EXTERNAL ${nxTargetArg})
				else()
					list(APPEND SOURCE_AGGREGATE ${nxTargetPathSource})
					list(APPEND SOURCEFULL_AGGREGATE "${CMAKE_CURRENT_SOURCE_DIR}/${nxTargetPathSource}")
				endif()
			else()
				list(APPEND SOURCE_AGGREGATE_BUILD ${nxTargetPathBuild})
				list(APPEND SOURCEFULL_AGGREGATE "${CMAKE_CURRENT_BINARY_DIR}/${nxTargetPathBuild}")
			endif()
		else()
			list(APPEND ${nxTargetMode}_AGGREGATE ${nxTargetArg})
		endif()
	endforeach()
	
	if("x${nxTargetType}" STREQUAL "xEXECUTABLE")
		list(APPEND nxTargetsToAdd ${nxTargetName})
		set(nxTargetExecutable ${nxTargetName})
	elseif("x${nxTargetType}" STREQUAL "xSHARED")
		list(APPEND nxTargetsToAdd ${nxTargetName})
		set(nxTargetShared ${nxTargetName})
	elseif("x${nxTargetType}" STREQUAL "xSTATIC")
		list(APPEND nxTargetsToAdd ${nxTargetName})
		set(nxTargetStatic ${nxTargetName})
	elseif("x${nxTargetType}" STREQUAL "xINLINE")
		list(APPEND nxTargetsToAdd ${nxTargetName})
		set(nxTargetInterface ${nxTargetName})
	elseif("x${nxTargetType}" STREQUAL "xLIBRARY")
		string(TOUPPER "${nxTargetName}_BUILD_SHARED" nxTargetBuildShared)
		string(TOUPPER "${nxTargetName}_BUILD_STATIC" nxTargetBuildStatic)
		string(TOUPPER "${nxTargetName}_BUILD_INLINE" nxTargetBuildInline)
		if(NOT DEFINED ${nxTargetBuildShared})
			if(DEFINED BUILD_SHARED_LIBS)
				set(${nxTargetBuildShared} ${BUILD_SHARED_LIBS})
			else()
				set(${nxTargetBuildShared} ON)
			endif()
		endif()
		if(NOT DEFINED ${nxTargetBuildStatic})
			set(${nxTargetBuildStatic} ON)
		endif()
		if(NOT DEFINED ${nxTargetBuildInline})
			set(${nxTargetBuildInline} ON)
		endif()
		if(${nxTargetBuildShared} OR ${nxTargetBuildStatic})
			if(${nxTargetBuildShared})
				list(APPEND nxTargetsToAdd ${nxTargetName})
				set(nxTargetShared ${nxTargetName})
				if(${nxTargetBuildStatic})
					list(APPEND nxTargetsToAdd "${nxTargetName}_static")
					set(nxTargetStatic "${nxTargetName}_static")
				endif()
			else()
				list(APPEND nxTargetsToAdd ${nxTargetName})
				set(nxTargetStatic ${nxTargetName})
			endif()
			if(${nxTargetBuildInline})
				list(APPEND nxTargetsToAdd "${nxTargetName}_inline")
				set(nxTargetInterface "${nxTargetName}_inline")
			endif()
		elseif(${nxTargetBuildInline})
			list(APPEND nxTargetsToAdd ${nxTargetName})
			set(nxTargetInterface ${nxTargetName})
		endif()
	endif()

	if(NOT DEFINED nxTargetVersion)
		set(nxTargetVersion ${PROJECT_VERSION})
		set(nxTargetPostfix "-${nxTargetVersion}")
	endif()

	if(DEFINED nxTargetExecutable)
		add_executable(${nxTargetExecutable} ${nxGuiMode} ${SOURCEFULL_AGGREGATE} ${SOURCE_AGGREGATE_EXTERNAL})
		set_target_properties(${nxTargetExecutable} PROPERTIES
			OUTPUT_NAME ${nxTargetName}
			VERSION ${PROJECT_VERSION})
		nx_target_compile_definitions(${nxTargetExecutable}
			PRIVATE ${DEFINE_AGGREGATE})
		nx_target_compile_options(${nxTargetExecutable}
			PRIVATE ${NX_COMPILER_FLAGS} ${NX_PIE_COMPILER_FLAGS} ${NX_LTO_COMPILER_FLAGS} ${COMPILE_FLAGS_AGGREGATE})
		nx_target_include_directories(${nxTargetExecutable}
			PRIVATE ${INCLUDE_AGGREGATE})
		nx_target_link_flags(${nxTargetExecutable}
			PRIVATE ${NX_LINKER_FLAGS} ${NX_PIE_LINKER_FLAGS} ${NX_LTO_LINKER_FLAGS} ${LINK_FLAGS_AGGREGATE})
		nx_target_link_libraries(${nxTargetExecutable}
			PRIVATE ${LINK_AGGREGATE})
		if(NX_CMAKE_INSTALL_PACKAGE AND nxTargetInstall)
			install(TARGETS ${nxTargetExecutable}
				COMPONENT binary
				RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
		endif()
	else()
		if(DEFINED nxTargetExport)
			get_filename_component(nxTargetExport "${nxTargetExport}" ABSOLUTE)
			file(RELATIVE_PATH nxTargetPathSource "${CMAKE_CURRENT_SOURCE_DIR}" "${nxTargetExport}")
			file(RELATIVE_PATH nxTargetPathBuild "${CMAKE_CURRENT_BINARY_DIR}" "${nxTargetExport}")
			string(SUBSTRING "${nxTargetPathSource}" 0 2 nxTargetPrefixSource)
			string(SUBSTRING "${nxTargetPathBuild}" 0 2 nxTargetPrefixBuild)
			if("x${nxTargetPrefixBuild}" STREQUAL "x..")
				if("x${nxTargetPrefixSource}" STREQUAL "x..")
					message(FATAL_ERROR "Cannot create EXPORT header in external directory.")
				else()
					set(nxTargetExport "${nxTargetPathSource}")
				endif()
			else()
				set(nxTargetExport "${nxTargetPathBuild}")
			endif()
			list(APPEND SOURCE_AGGREGATE_BUILD "${nxTargetExport}/${nxTargetName}_export.h")
			list(APPEND SOURCEFULL_AGGREGATE "${CMAKE_CURRENT_BINARY_DIR}/${nxTargetExport}/${nxTargetName}_export.h")
			list(INSERT INCLUDE_AGGREGATE 0 "${nxTargetExport}")
		endif()
	endif()

	if(DEFINED nxTargetShared)
		string(TOUPPER "${nxTargetName}_EXPORTS" nxTargetDefinition)
		string(MAKE_C_IDENTIFIER ${nxTargetDefinition} nxTargetDefinition)
		add_library(${nxTargetShared} SHARED ${SOURCEFULL_AGGREGATE} ${SOURCE_AGGREGATE_EXTERNAL})
		if(WIN32)
			set_target_properties(${nxTargetShared} PROPERTIES
				OUTPUT_NAME "${nxTargetName}${nxTargetPostfix}")
		else()
			set_target_properties(${nxTargetShared} PROPERTIES
				OUTPUT_NAME ${nxTargetName})
		endif()
		set_target_properties(${nxTargetShared} PROPERTIES
			DEFINE_SYMBOL ${nxTargetDefinition}
			SOVERSION ${nxTargetVersion}
			VERSION ${PROJECT_VERSION})
		nx_target_compile_definitions(${nxTargetShared}
			PRIVATE ${DEFINE_AGGREGATE})
		nx_target_compile_options(${nxTargetShared}
			PRIVATE ${NX_COMPILER_FLAGS} ${NX_LTO_COMPILER_FLAGS} ${COMPILE_FLAGS_AGGREGATE})
		nx_target_include_directories(${nxTargetShared}
			INSTALL "${nxTargetName}${nxTargetPostfix}"
			PUBLIC ${INCLUDE_AGGREGATE})
		nx_target_link_flags(${nxTargetShared}
			PRIVATE ${NX_LINKER_FLAGS} ${NX_LTO_LINKER_FLAGS} ${LINK_FLAGS_AGGREGATE})
		nx_target_link_libraries(${nxTargetShared}
			PRIVATE ${LINK_AGGREGATE})
		if(nxTargetInstall)
			install(TARGETS ${nxTargetShared}
				EXPORT "${nxTargetName}${NXP}"
				COMPONENT shared
				RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
				LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
				ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
			list(APPEND CPACK_COMPONENT_BINARY_DEPENDS shared)
			list(APPEND CPACK_COMPONENT_EXPORT_DEPENDS shared)
			set(CPACK_COMPONENT_BINARY_DEPENDS ${CPACK_COMPONENT_BINARY_DEPENDS}
				PARENT_SCOPE)
			set(CPACK_COMPONENT_EXPORT_DEPENDS ${CPACK_COMPONENT_EXPORT_DEPENDS}
				PARENT_SCOPE)
		endif()
	endif()

	if(DEFINED nxTargetStatic)
		string(TOUPPER "${nxTargetName}_STATIC_DEFINE" nxTargetDefinition)
		string(MAKE_C_IDENTIFIER ${nxTargetDefinition} nxTargetDefinition)
		add_library(${nxTargetStatic} STATIC ${SOURCEFULL_AGGREGATE} ${SOURCE_AGGREGATE_EXTERNAL})
		if(MSVC)
			set_target_properties(${nxTargetStatic} PROPERTIES
				OUTPUT_NAME "${nxTargetName}${nxTargetPostfix}_static")
		else()
			set_target_properties(${nxTargetStatic} PROPERTIES
				OUTPUT_NAME "${nxTargetName}${nxTargetPostfix}")
		endif()
		nx_target_compile_definitions(${nxTargetStatic}
			PUBLIC ${nxTargetDefinition}
			PRIVATE ${DEFINE_AGGREGATE})
		nx_target_compile_options(${nxTargetStatic}
			PRIVATE ${NX_COMPILER_FLAGS} ${NX_LTO_SAFE_COMPILER_FLAGS} ${COMPILE_FLAGS_AGGREGATE})
		nx_target_include_directories(${nxTargetStatic}
			INSTALL "${nxTargetName}${nxTargetPostfix}"
			PUBLIC ${INCLUDE_AGGREGATE})
		nx_target_link_libraries(${nxTargetStatic}
			FORCE_INTERFACE ${LINK_AGGREGATE})
		if(NX_CMAKE_INSTALL_PACKAGE AND nxTargetInstall)
			install(TARGETS ${nxTargetStatic}
				EXPORT "${nxTargetName}${NXP}"
				COMPONENT static
				LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
				ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
			list(APPEND CPACK_COMPONENT_EXPORT_DEPENDS static)
			set(CPACK_COMPONENT_EXPORT_DEPENDS ${CPACK_COMPONENT_EXPORT_DEPENDS}
				PARENT_SCOPE)
		endif()
	endif()

	if(DEFINED nxTargetInterface)
		string(TOUPPER "${nxTargetName}_STATIC_DEFINE" nxTargetDefinition)
		string(MAKE_C_IDENTIFIER ${nxTargetDefinition} nxTargetDefinition)
		add_library(${nxTargetInterface} INTERFACE)
		foreach(nxSourceFile ${SOURCE_AGGREGATE})
			target_sources(${nxTargetInterface} INTERFACE
				$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${nxSourceFile}>)
		endforeach()
		foreach(nxSourceFile ${SOURCE_AGGREGATE_BUILD})
			target_sources(${nxTargetInterface} INTERFACE
				$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/${nxSourceFile}>)
		endforeach()
		target_sources(${nxTargetInterface}
			INTERFACE ${SOURCE_AGGREGATE_EXTERNAL})
		nx_target_compile_definitions(${nxTargetInterface}
			FORCE_INTERFACE ${nxTargetDefinition} ${DEFINE_AGGREGATE})
		nx_target_include_directories(${nxTargetInterface}
			INSTALL "${nxTargetName}${nxTargetPostfix}"
			FORCE_INTERFACE ${INCLUDE_AGGREGATE})
		nx_target_link_libraries(${nxTargetInterface}
			FORCE_INTERFACE ${LINK_AGGREGATE})
		if(NX_CMAKE_INSTALL_PACKAGE AND nxTargetInstall)
			get_target_property(nxTargetAllDirs ${nxTargetName} INTERFACE_INCLUDE_DIRECTORIES)
			install(TARGETS ${nxTargetInterface}
				EXPORT "${nxTargetName}${NXP}"
				COMPONENT intlib)
			foreach(nxSourceFile ${SOURCE_AGGREGATE})
				get_filename_component(nxSourceDirectory "${nxSourceFile}" DIRECTORY)
				set(nxSourceExcluded OFF)
				set(nxSourceTemp ${nxSourceDirectory})
				while(NOT nxSourceExcluded AND NOT "x${nxSourceTemp}" STREQUAL "x")
					if("$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${nxSourceTemp}>" IN_LIST nxTargetAllDirs)
						set(nxSourceExcluded ON)
					endif()
					get_filename_component(nxSourceTemp "${nxSourceTemp}" DIRECTORY)
				endwhile()
				if(NOT nxSourceExcluded)
					if(DEFINED nxTargetBase)
						string(REGEX REPLACE "^${nxTargetBase}" "" nxSourceDirectory ${nxSourceDirectory})
					endif()
					install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/${nxSourceFile}"
						DESTINATION "src/${nxTargetName}${nxTargetPostfix}/${nxSourceDirectory}"
						COMPONENT intlib)
					if(DEFINED nxTargetBase)
						string(REGEX REPLACE "^${nxTargetBase}" "" nxSourceFile ${nxSourceFile})
					endif()
					target_sources(${nxTargetInterface} INTERFACE
						$<INSTALL_INTERFACE:src/${nxTargetName}${nxTargetPostfix}/${nxSourceFile}>)
				endif()
			endforeach()
			foreach(nxSourceFile ${SOURCE_AGGREGATE_BUILD})
				get_filename_component(nxSourceDirectory "${nxSourceFile}" DIRECTORY)
				set(nxSourceExcluded OFF)
				set(nxSourceTemp ${nxSourceDirectory})
				while(NOT nxSourceExcluded AND NOT "x${nxSourceTemp}" STREQUAL "x")
					if("$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/${nxSourceTemp}>" IN_LIST nxTargetAllDirs)
						set(nxSourceExcluded ON)
					endif()
					get_filename_component(nxSourceTemp "${nxSourceTemp}" DIRECTORY)
				endwhile()
				if(NOT nxSourceExcluded)
					if(DEFINED nxTargetBase)
						string(REGEX REPLACE "^${nxTargetBase}" "" nxSourceDirectory ${nxSourceDirectory})
					endif()
					install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${nxSourceFile}"
						DESTINATION "src/${nxTargetName}${nxTargetPostfix}/${NX_BUILD_DIR}/${nxSourceDirectory}"
						COMPONENT intlib)
					if(DEFINED nxTargetBase)
						string(REGEX REPLACE "^${nxTargetBase}" "" nxSourceFile ${nxSourceFile})
					endif()
					target_sources(${nxTargetInterface} INTERFACE
						$<INSTALL_INTERFACE:src/${nxTargetName}${nxTargetPostfix}/${NX_BUILD_DIR}/${nxSourceFile}>)
				endif()
			endforeach()
			list(APPEND CPACK_COMPONENT_EXPORT_DEPENDS intlib)
			set(CPACK_COMPONENT_EXPORT_DEPENDS ${CPACK_COMPONENT_EXPORT_DEPENDS}
				PARENT_SCOPE)
		endif()
	endif()

	if(NOT DEFINED nxTargetExecutable)
		if(DEFINED nxTargetExport)
			generate_export_header(${nxTargetName} BASE_NAME ${nxTargetName}
				EXPORT_FILE_NAME "${CMAKE_CURRENT_BINARY_DIR}/${nxTargetExport}/${nxTargetName}_export.h")
		endif()
		if(NX_CMAKE_INSTALL_PACKAGE AND nxTargetInstall)
			if(NX_CMAKE_EXPORT_BUILD)
				export(EXPORT "${nxTargetName}${NXP}" FILE "${nxTargetName}${NXP}Config.cmake")
				export(PACKAGE "${nxTargetName}${NXP}")
			endif()
			write_basic_package_version_file("${nxTargetName}${NXP}ConfigVersion.cmake"
				VERSION ${nxTargetVersion}
				COMPATIBILITY ExactVersion)
			install(EXPORT "${nxTargetName}${NXP}"
				FILE "${nxTargetName}${NXP}Config.cmake"
				DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${nxTargetName}${NXP}${nxTargetPostfix}"
				COMPONENT export)
			install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${nxTargetName}${NXP}ConfigVersion.cmake"
				DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${nxTargetName}${NXP}${nxTargetPostfix}"
				COMPONENT export)
			list(APPEND CPACK_COMPONENT_APIREF_DEPENDS headers)
			list(APPEND CPACK_COMPONENT_EXPORT_DEPENDS headers)
			list(APPEND CPACK_COMPONENT_INTLIB_DEPENDS headers)
			list(APPEND CPACK_COMPONENT_STATIC_DEPENDS headers)
			set(CPACK_COMPONENT_APIREF_DEPENDS ${CPACK_COMPONENT_APIREF_DEPENDS}
				PARENT_SCOPE)
			set(CPACK_COMPONENT_EXPORT_DEPENDS ${CPACK_COMPONENT_EXPORT_DEPENDS}
				PARENT_SCOPE)
			set(CPACK_COMPONENT_INTLIB_DEPENDS ${CPACK_COMPONENT_INTLIB_DEPENDS}
				PARENT_SCOPE)
			set(CPACK_COMPONENT_STATIC_DEPENDS ${CPACK_COMPONENT_STATIC_DEPENDS}
				PARENT_SCOPE)
		endif()
	endif()

	if(WIN32 AND (DEFINED nxTargetExecutable OR DEFINED nxTargetShared))
		get_target_property(nxTargetLinkedLibs ${nxTargetName} LINK_LIBRARIES)
		foreach(nxTargetLinkedLib ${nxTargetLinkedLibs})
			if(TARGET ${nxTargetLinkedLib})
				get_target_property(nxTargetLinkedType ${nxTargetLinkedLib} TYPE)
				if(NOT "x${nxTargetLinkedType}" STREQUAL "xINTERFACE_LIBRARY")
					string(TOUPPER "IMPORTED_LOCATION_${CMAKE_BUILD_TYPE}" nxTargetConfig)
					get_target_property(nxTargetImportDLL ${nxTargetLinkedLib} ${nxTargetConfig})
					if(NOT EXISTS "${nxTargetImportDLL}")
						get_target_property(nxTargetImportDLL ${nxTargetLinkedLib} IMPORTED_LOCATION_RELEASE)
						if(NOT EXISTS "${nxTargetImportDLL}")
							get_target_property(nxTargetImportDLL ${nxTargetLinkedLib} IMPORTED_LOCATION)
						endif()
					endif()
				endif()
				if(EXISTS "${nxTargetImportDLL}")
					if(MSVC)
						file(COPY "${nxTargetImportDLL}" DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/Release")
						file(COPY "${nxTargetImportDLL}" DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/Debug")
					else()
						file(COPY "${nxTargetImportDLL}" DESTINATION "${CMAKE_CURRENT_BINARY_DIR}")
					endif()
					list(APPEND CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS "${nxTargetImportDLL}")
				endif()
			endif()
		endforeach()
		if(MINGW AND DEFINED nxTargetExecutable)
			if("CXX" IN_LIST NX_CMAKE_ENABLED_LANGUAGES)
				foreach(nxCompilerDLL "libgcc_s_dw2-1.dll" "libgcc_s_seh-1.dll" "libwinpthread-1.dll" "libstdc++-6.dll")
					execute_process(COMMAND ${CMAKE_CXX_COMPILER} --print-file-name=${nxCompilerDLL}
						OUTPUT_VARIABLE nxMinGWLib
						OUTPUT_STRIP_TRAILING_WHITESPACE)
					if(EXISTS "${nxMinGWLib}")
						list(APPEND CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS "${nxMinGWLib}")
					else()
						get_filename_component(nxCompilerPath ${CMAKE_CXX_COMPILER} PATH)
						if(EXISTS "${nxCompilerPath}/${nxCompilerDLL}")
							list(APPEND CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS "${nxCompilerPath}/${nxCompilerDLL}")
						endif()
					endif()
				endforeach()
			else()
				foreach(nxCompilerDLL "libgcc_s_dw2-1.dll" "libgcc_s_seh-1.dll" "libwinpthread-1.dll")
					execute_process(COMMAND ${CMAKE_C_COMPILER} --print-file-name=${nxCompilerDLL}
						OUTPUT_VARIABLE nxMinGWLib
						OUTPUT_STRIP_TRAILING_WHITESPACE)
					if(EXISTS "${nxMinGWLib}")
						list(APPEND CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS "${nxMinGWLib}")
					else()
						get_filename_component(nxCompilerPath ${CMAKE_C_COMPILER} PATH)
						if(EXISTS "${nxCompilerPath}/${nxCompilerDLL}")
							list(APPEND CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS "${nxCompilerPath}/${nxCompilerDLL}")
						endif()
					endif()
				endforeach()
			endif()
		endif()
		set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS}
			PARENT_SCOPE)
	endif()

	set(NX_SOURCE_FILES ${NX_SOURCE_FILES} ${SOURCEFULL_AGGREGATE}
		PARENT_SCOPE)
	set(${nxParentVariable}_EXECUTABLE ${${nxParentVariable}_EXECUTABLE} ${nxTargetExecutable}
		PARENT_SCOPE)
	set(${nxParentVariable}_SHARED ${${nxParentVariable}_SHARED} ${nxTargetShared}
		PARENT_SCOPE)
	set(${nxParentVariable}_STATIC ${${nxParentVariable}_STATIC} ${nxTargetStatic}
		PARENT_SCOPE)
	set(${nxParentVariable}_SOURCE ${${nxParentVariable}_SOURCE} ${nxTargetInterface}
		PARENT_SCOPE)
	set(${nxParentVariable} ${${nxParentVariable}} ${nxTargetsToAdd}
		PARENT_SCOPE)
endfunction()

# -------------------------------
# misc functions
#

function(nx_qol)
	if(DEFINED NX_SOURCE_FILES)
		list(REMOVE_DUPLICATES NX_SOURCE_FILES)
		foreach(nxSourceAbsolute ${NX_SOURCE_FILES})
			get_filename_component(nxSourceAbsolute "${nxSourceAbsolute}" ABSOLUTE)
			get_filename_component(nxSourcePath "${nxSourceAbsolute}" PATH)
			file(RELATIVE_PATH nxSourcePathSource "${CMAKE_CURRENT_SOURCE_DIR}" "${nxSourcePath}")
			file(RELATIVE_PATH nxSourcePathBuild "${CMAKE_CURRENT_BINARY_DIR}" "${nxSourcePath}")
			string(SUBSTRING "${nxSourcePathSource}" 0 2 nxSourcePrefixSource)
			string(SUBSTRING "${nxSourcePathBuild}" 0 2 nxSourcePrefixBuild)
			if("x${nxSourcePrefixSource}" STREQUAL "x..")
				set(nxSourceRelative "${PROJECT_NAME}/${NX_BUILD_DIR}/${nxSourcePathBuild}")
			else()
				set(nxSourceRelative "${PROJECT_NAME}/${nxSourcePathSource}")
			endif()
			string(REPLACE "/" "\\" nxSourceGroup "${nxSourceRelative}")
			source_group("${nxSourceGroup}" FILES "${nxSourceAbsolute}")
		endforeach()
		if(CLANG_FORMAT_FOUND)
			list(REMOVE_DUPLICATES NX_SOURCE_FILES)
			add_custom_target(format
				COMMAND ${CLANG_FORMAT_EXECUTABLE} -i ${NX_SOURCE_FILES}
				WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
				COMMENT "[CLANG-FORMAT] Performing Style Formatting")
		endif()
	endif()
endfunction()

# -------------------------------
# nx_package
#

function(nx_package)
	nx_qol()
	set(nxPackageMode DESCRIPTION)
	set(nxPackageSubMode DESCRIPTION_SUMMARY)
	foreach(nxPackageArg ${ARGN})
		if("x${nxPackageArg}" STREQUAL "xCATEGORY")
			set(nxPackageMode CATEGORY)
			set(nxPackageSubMode CATEGORY_DEBIAN)
		elseif("x${nxPackageMode}" STREQUAL "xCATEGORY" AND "x${nxPackageArg}" STREQUAL "xDEBIAN")
			set(nxPackageSubMode CATEGORY_DEBIAN)
		elseif("x${nxPackageMode}" STREQUAL "xCATEGORY" AND "x${nxPackageArg}" STREQUAL "xRPM")
			set(nxPackageSubMode CATEGORY_RPM)
		elseif("x${nxPackageArg}" STREQUAL "xDESCRIPTION")
			set(nxPackageMode DESCRIPTION)
			set(nxPackageSubMode DESCRIPTION_SUMMARY)
		elseif("x${nxPackageMode}" STREQUAL "xDESCRIPTION" AND "x${nxPackageArg}" STREQUAL "xREADME")
			set(nxPackageSubMode DESCRIPTION_README)
		elseif("x${nxPackageMode}" STREQUAL "xDESCRIPTION" AND "x${nxPackageArg}" STREQUAL "xSUMMARY")
			set(nxPackageSubMode DESCRIPTION_SUMMARY)
		elseif("x${nxPackageArg}" STREQUAL "xLICENSE")
			set(nxPackageMode LICENSE)
			set(nxPackageSubMode LICENSE_NAME)
		elseif("x${nxPackageMode}" STREQUAL "xLICENSE" AND "x${nxPackageArg}" STREQUAL "xFILE")
			set(nxPackageSubMode LICENSE_FILE)
		elseif("x${nxPackageMode}" STREQUAL "xLICENSE" AND "x${nxPackageArg}" STREQUAL "xNAME")
			set(nxPackageSubMode LICENSE_NAME)
		elseif("x${nxPackageArg}" STREQUAL "xUPSTREAM")
			set(nxPackageMode UPSTREAM)
			set(nxPackageSubMode UPSTREAM_URL)
		elseif("x${nxPackageArg}" STREQUAL "xVENDOR")
			set(nxPackageMode VENDOR)
			set(nxPackageSubMode VENDOR_NAME)
		elseif("x${nxPackageMode}" STREQUAL "xVENDOR" AND "x${nxPackageArg}" STREQUAL "xCONTACT")
			set(nxPackageSubMode VENDOR_CONTACT)
		elseif("x${nxPackageMode}" STREQUAL "xVENDOR" AND "x${nxPackageArg}" STREQUAL "xNAME")
			set(nxPackageSubMode VENDOR_NAME)
		elseif("x${nxPackageMode}" STREQUAL "xVENDOR" AND "x${nxPackageArg}" STREQUAL "xURL")
			set(nxPackageSubMode VENDOR_URL)
		elseif("x${nxPackageSubMode}" STREQUAL "xCATEGORY_DEBIAN")
			set(CPACK_DEBIAN_PACKAGE_SECTION ${nxPackageArg})
		elseif("x${nxPackageSubMode}" STREQUAL "xCATEGORY_RPM")
			set(CPACK_RPM_PACKAGE_GROUP ${nxPackageArg})
		elseif("x${nxPackageSubMode}" STREQUAL "xDESCRIPTION_README")
			set(CPACK_PACKAGE_DESCRIPTION_FILE ${nxPackageArg})
			set(CPACK_RESOURCE_FILE_README ${nxPackageArg})
		elseif("x${nxPackageSubMode}" STREQUAL "xDESCRIPTION_SUMMARY")
			set(CPACK_PACKAGE_DESCRIPTION_SUMMARY ${nxPackageArg})
		elseif("x${nxPackageSubMode}" STREQUAL "xLICENSE_FILE")
			set(CPACK_RESOURCE_FILE_LICENSE ${nxPackageArg})
		elseif("x${nxPackageSubMode}" STREQUAL "xLICENSE_NAME")
			set(CPACK_RPM_PACKAGE_LICENSE ${nxPackageArg})
		elseif("x${nxPackageSubMode}" STREQUAL "xUPSTREAM_URL")
			set(CPACK_DEBIAN_PACKAGE_HOMEPAGE ${nxPackageArg})
			set(CPACK_NSIS_URL_INFO_ABOUT ${nxPackageArg})
			set(CPACK_RPM_PACKAGE_URL ${nxPackageArg})
		elseif("x${nxPackageSubMode}" STREQUAL "xVENDOR_CONTACT")
			set(CPACK_PACKAGE_CONTACT ${nxPackageArg})
		elseif("x${nxPackageSubMode}" STREQUAL "xVENDOR_NAME")
			set(CPACK_PACKAGE_VENDOR ${nxPackageArg})
		elseif("x${nxPackageSubMode}" STREQUAL "xVENDOR_URL")
			set(CPACK_NSIS_HELP_LINK ${nxPackageArg})
			if(NOT DEFINED CPACK_DEBIAN_PACKAGE_HOMEPAGE)
				set(CPACK_DEBIAN_PACKAGE_HOMEPAGE ${nxPackageArg})
			endif()
			if(NOT DEFINED CPACK_NSIS_URL_INFO_ABOUT)
				set(CPACK_NSIS_URL_INFO_ABOUT ${nxPackageArg})
			endif()
			if(NOT DEFINED CPACK_RPM_PACKAGE_URL)
				set(CPACK_RPM_PACKAGE_URL ${nxPackageArg})
			endif()
		endif()
	endforeach()

	foreach(nxPackageGenerator 7Z TGZ TXZ ZIP)
		if(NX_PACKAGE_USE_${nxPackageGenerator})
			list(APPEND NX_BUILD_GENERATORS ${nxPackageGenerator})
			list(APPEND NX_SOURCE_GENERATORS ${nxPackageGenerator})
		endif()
	endforeach()
	foreach(nxPackageGenerator DEB NSIS RPM)
		if(NX_INSTALLER_USE_${nxPackageGenerator})
			list(APPEND NX_BUILD_GENERATORS ${nxPackageGenerator})
		endif()
	endforeach()

	set(CPACK_GENERATOR ${NX_BUILD_GENERATORS})
	set(CPACK_PACKAGE_INSTALL_DIRECTORY ${CPACK_PACKAGE_VENDOR})
	set(CPACK_PACKAGE_RELOCATABLE ON)
	set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
	set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
	set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
	set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
	set(CPACK_DEBIAN_ARCHIVE_TYPE gnutar)
	set(CPACK_DEBIAN_COMPRESSION_TYPE bzip2)
	set(CPACK_DEBIAN_PACKAGE_GENERATE_SHLIBS ON)
	set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
	set(CPACK_NSIS_DISPLAY_NAME "${PROJECT_NAME} (${CPACK_PACKAGE_VERSION})")
	set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
	set(CPACK_NSIS_MODIFY_PATH ON)
	set(CPACK_NSIS_PACKAGE_NAME "${PROJECT_NAME} ${CPACK_PACKAGE_VERSION}")
	set(CPACK_RPM_COMPRESSION_TYPE bzip2)
	set(CPACK_RPM_PACKAGE_AUTOPROV ON)
	set(CPACK_RPM_PACKAGE_AUTOREQ ON)
	set(CPACK_SOURCE_GENERATOR ${NX_SOURCE_GENERATORS})
	set(CPACK_SOURCE_IGNORE_FILES "\\\\.#;/#;.*~"
		"/\\\\.git"
		"/\\\\.svn"
		"appveyor.yml"
		"travis.yml"
		"${CMAKE_CURRENT_SOURCE_DIR}/build"
		"${CMAKE_CURRENT_BINARY_DIR}")
	set(CPACK_STRIP_FILES ON)
	
	string(TOLOWER "${PROJECT_NAME}" CPACK_PACKAGE_NAME)
	string(TOLOWER "${CPACK_PACKAGE_NAME}_${CPACK_PACKAGE_VERSION}_source-noarch" CPACK_SOURCE_PACKAGE_FILE_NAME)
	if(MINGW)
		set(nxPackageOS mingw)
	else()
		set(nxPackageOS ${CMAKE_SYSTEM_NAME})
	endif()
	if("x${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "xAMD64" OR "x${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "x")
		if(CMAKE_SIZEOF_VOID_P EQUAL 8)
			set(nxPackageArch x86_64)
		else()
			set(nxPackageArch i686)
		endif()
	else()
		set(nxPackageArch ${CMAKE_SYSTEM_PROCESSOR})
	endif()
	string(TOLOWER "${CPACK_PACKAGE_NAME}_${CPACK_PACKAGE_VERSION}_${nxPackageOS}-${nxPackageArch}" CPACK_PACKAGE_FILE_NAME)
	if(DEFINED NX_BUILD_GENERATORS)
		include(CPack)
	endif()
endfunction()

cmake_policy(POP)
