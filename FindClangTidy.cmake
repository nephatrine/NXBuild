find_program(CLANG_TIDY_EXECUTABLE NAMES clang-tidy
	clang-tidy-5.0
	clang-tidy-4.0
	clang-tidy-3.9
	clang-tidy-3.8
	clang-tidy-3.7
	clang-tidy-3.6)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(CLANG_TIDY DEFAULT_MSG CLANG_TIDY_EXECUTABLE)

mark_as_advanced(CLANG_TIDY_EXECUTABLE)
