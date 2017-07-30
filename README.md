# NXBuild

NXBuild is a quick-and-dirty CMake module created to speed up project configuration for our tools
and internal projects. It will have very little utility if your projects don't have the exact same
requirements as our own.

## Requirements

- **CMake 3.3+**

These tools enable optional integrations and functionality if found in the standard paths:

- **clang-format**: Enables the 'format' target which just runs ``clang-format`` on the project's
  source code. Does not specify arguments as you are expected to provide you own ``.clang-format``
  file in the source directory.
- **dpkg**: Allows Debian-style ``deb`` installation packages to be generated when running on a
  Linux system.
- **makensis**: Allows Nullsoft installers to be generated when compiling for a Windows system.
- **rpm**: Allows Red Hat-style ``rpm`` installation packages to be generated when running on a
  Linux system.

Some tools are only supported if Clang is detected the compiler to stave off errors due to
unsupported compiler flags:

- **clang-tidy**: Allows CMake to automatically run ``clang-tidy`` analysis on the source files
  during compilation. You are expected to provide your own ``.clang-tidy`` file in the source
  directory to configure the checks.
- **include-what-you-use**: Allows CMake to automatically run ``include-what-you-use`` analysis on
  the source files during compilation.
  
## Minimal Usage Example

Detailed usage information for the various functions will follow.

```CMake
cmake_minimum_required(VERSION 3.3)
project(HelloWorld LANGUAGES CXX VERSION 1.0.0)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/CMake")
include(NXBuild)
nx_config()
nx_target(HELLOWORLD_TARGET hello-world EXECUTABLE "hello.cpp")
nx_documentation(README.md COPYRIGHT LICENSE.md)
nx_package( "Toy program used as an example." CATEGORY "misc" LICENSE "ISC")
add_test(NAME ${HELLOWORLD_TARGET} COMMAND ${HELLOWORLD_TARGET})
```

## Functions

### nx_config

```
nx_config([COMPILE_FLAGS flags ...] [LINK_FLAGS flags ...]
          [C required-standard] [CXX required-standard]
          [SECURE])
```

Performs checks to determine whether various flags are supported and stores them in the variables
``NX_COMPILER_FLAGS`` and ``NX_LINKER_FLAGS``. Flags included are fairly "standard" and widely
applicable. The flags that return success will be automatically added to build targets.

To automatically enable additional standard flags for security-hardening, the ``SECURE`` parameter
may be passed as a convenience function rather than having to specify the additional flags manually.

Additionally, support is checked for PIE (Position Independent Executables) and LTO (Link-Time
Optimization) as built-in CMake support for these settings are substandard. These flags are only
enabled if the related CMake options are enabled in the configuration.

### nx_documentation

```
nx_documentation([[DOCUMENTS] documents ...]
                 [COPYRIGHT licences ...]
                 [REFERENCE apirefs ...])
```

Declares what documentation is tied to the project. The listed documents can be files or folders
and will be installed alongside the project. Licenses and API references (e.g. doxygen docs) are
listed separately so they appear as separate components in installers that support that.

### nx_package

```
nx_package([[DESCRIPTION] description-summary]
           [VENDOR [[NAME] vendor-name] [CONTACT vendor-email] [URL vendor-url]]
           [CATEGORY [[DEBIAN] debian-section] [RPM redhat-group]]
           [LICENSE license-shortname]
           [UPSTREAM upstream-url])
```           

Creates ``package`` and ``package_source`` targets if enabled. Also performs various cleanup tasks
that must be performed after all build targets are declared.

By default, packages will not be created if project is included as a subdirectory of another project
as that is typically not desired in such cases. If the project is a component of an "over-project"
and should still generate full packaging and installation routines then the following code should
be in the "over-project" ``CMakeLists.txt`` file prior to adding the subdirectory:

```CMake
if(CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
    set(NX_CMAKE_CONTAINER_PROJECT ON)
endif()
```

Such "over-projects" should generally ``enable_testing()`` as well to ensure test cases can be ran.

### nx_target

```
nx_target(<variable> <target> EXECUTABLE [[SOURCE] sources ...]
          [COMPILE_FLAGS [PRIVATE] flags ...] [DEFINE [PRIVATE] definitions ...]
          [INCLUDE [PRIVATE] directories ...] [LINK [PRIVATE] libraries ...]
          [LINK_FLAGS [PRIVATE] flags ...] [GUI] [NO_INSTALL])
```

``EXECUTABLE``: Creates an executable program binary. Supplying the ``GUI`` option will disable the
separate console window on non-debug Windows builds, but retains the ``main()`` entrypoint.

```
nx_target(<variable> <target> SHARED [[SOURCE] sources ...]
          [APIVERSION version] [EXPORT export-header-dir]
          [COMPILE_FLAGS [[PRIVATE] flags ...] [PUBLIC flags ...] [INTERFACE flags ...]]
          [DEFINE [[PRIVATE] definitions ...] [PUBLIC definitions ...] [INTERFACE definitions ...]]
          [INCLUDE [[PUBLIC] directories ...] [INTERFACE directories ...] [PRIVATE directories ...]]
          [LINK [[PRIVATE] libraries ...] [PUBLIC libraries ...] [INTERFACE libraries ...]]
          [LINK_FLAGS [PRIVATE] flags ...] [NO_INSTALL])
```

``SHARED``: Creates a shared object or dll library. The export-header will be named
``<target>_export.h`` and define a macro ``<TARGET>_EXPORT`` which will properly export definitions
when the shared library is built and import them when used by client code.

```
nx_target(<variable> <target> STATIC [[SOURCE] sources ...]
          [APIVERSION version] [EXPORT export-header-dir]
          [COMPILE_FLAGS [[PRIVATE] flags ...] [PUBLIC flags ...] [INTERFACE flags ...]]
          [DEFINE [[PRIVATE] definitions ...] [PUBLIC definitions ...] [INTERFACE definitions ...]]
          [INCLUDE [[PUBLIC] directories ...] [INTERFACE directories ...] [PRIVATE directories ...]]
          [LINK [INTERFACE] libraries ...] [NO_INSTALL])
```

``STATIC``: Creates a static library or archive.

```
nx_target(<variable> <target> INLINE [[SOURCE] sources ...]
          [APIVERSION version] [EXPORT export-header-dir]
          [DEFINE [INTERFACE] definitions ...] [INCLUDE [INTERFACE] directories ...]
          [LINK [INTERFACE] libraries ...] [BASE_DIR source-dir] [NO_INSTALL])
```

``INLINE``: Creates a non-compiled library target. This can be for header-only libraries or
libraries where the source should be included directly into the project code.

```
nx_target(<variable> <target> LIBRARY [[SOURCE] sources ...]
          [APIVERSION version] [EXPORT export-header-dir]
          [COMPILE_FLAGS [[PRIVATE] flags ...] [PUBLIC flags ...] [INTERFACE flags ...]]
          [DEFINE [[PRIVATE] definitions ...] [PUBLIC definitions ...] [INTERFACE definitions ...]]
          [INCLUDE [[PUBLIC] directories ...] [INTERFACE directories ...] [PRIVATE directories ...]]
          [LINK [[PRIVATE] libraries ...] [PUBLIC libraries ...] [INTERFACE libraries ...]]
          [LINK_FLAGS [PRIVATE] flags ...] [BASE_DIR source-dir] [NO_INSTALL])
```

``LIBRARY``: This is a smart target that can create multiple library types. By default it will
create ``SHARED``, ``STATIC``, and ``INLINE`` targets. The ``BUILD_SHARED_LIBS`` CMake setting can
toggle whether the ``SHARED`` target is built. The options ``<TARGET>_BUILD_<TYPE>`` can also be
defined and will control whether those specific targets are built (overriding the
``BUILD_SHARED_LIBS`` setting).

The target names will all be appended to the returned variable. The "default" target (i.e. target
without a suffix) will be the ``SHARED``, ``STATIC``, or ``INLINE`` target if built, in that order
of preference. The remaining targets will be named ``<target>_<type>``. In client code if you would
prefer to link with the static version of a library, if available, you can check like this:

```CMake
nx_find_package(<target> REQUIRED)
if(TARGET <target>_static)
    set(TARGET_LINK <target>_static)
else()
    set(TARGET_LINK <target>)
endif()
nx_target(... LINK ${TARGET_LINK})
```

## Finding Packages

Rather than missing with ``Find<Package>.cmake`` modules or ``ExternalProject`` commands, NXBuild
relies heavily on ``<Package>Config.cmake`` files. These are installed in the standardized path that
CMake checks to resolve ``find_package`` commands and import the relevant targets and their
interface requirements without any extra work on your part.

By default, NXBuild will not only install the configuration files in
``<install_path>/lib/CMake/<target>-<version>/`` where it can be found by CMake, but will also
export a config file into the build directory meaning you may not need to explicitly install
libraries purely used as a dependency before using them; you merely need to build them.

If you have installed packages to a non-standard location (e.g. your home directory or ``/opt``),
then you will likely need to point CMake to that location so it can find the packages. You can do
this by using the ``-DCMAKE_PREFIX_PATH=<path>`` option when generating the CMake build.
Dependencies in the standard system install path or ``CMAKE_INSTALL_PREFIX`` never need to be
explicitly added to the ``CMAKE_PREFIX_PATH``:

- Building in home directory which is also where dependency projects are installed:
  - ``cmake -DCMAKE_INSTALL_PREFIX=${HOME}/.local ..``
- Building in /opt directory which is also where dependency projects are installed:
  - ``cmake -DCMAKE_INSTALL_PREFIX=/opt/myprojects ..``
- Building in /opt directory but dependencies are in another /opt directory:
  - ``cmake -DCMAKE_PREFIX_PATH=/opt/otherlibs -DCMAKE_INSTALL_PREFIX=/opt/myprojects ..``

Then to import the targets for the dependency, use the ``nx_find_package`` command with the same
syntax you'd use in plain old ``find_package``. If both debug and release versions of a library
are installed, this will always default to pulling in the release build, but the debug build can be
explicitly called for:

- import release build always:
  - ``nx_find_package(otherlib ...)``
- import debug build always:
  - ``nx_find_package(otherlibDebug ...)``
- try importing debug build, but fall-back to release build:
  - ``nx_find_package(otherlib NAMES otherlibDebug otherlib ...)``

Even though debug builds are not typically installed, by default NXBuild will export a config for
the build directories and so this avoids confusion between which configuration will be imported.
Without this logic, you could inadvertently pull in a debug library from a build directory and
compile it into your release program.

There is also logic built in that allows you to install MinGW and MSVC libraries side-by-side
without any confusion when pulling dependencies. ``nx_find_package`` will only pull in
MinGW-compiled libraries when you're building with MinGW and will only pull in MSVC libraries when
compiling using MSVC. This also means you won't inadvertently pull in a build directory from a
native GNU/Linux system when cross-compiling for Windows with MinGW (and vice versa).
