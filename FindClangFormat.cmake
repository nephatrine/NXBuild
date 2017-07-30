find_program(CLANG_FORMAT_EXECUTABLE NAMES clang-format
	clang-format-5.0
	clang-format-4.0
	clang-format-3.9
	clang-format-3.8
	clang-format-3.7
	clang-format-3.6)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(CLANG_FORMAT DEFAULT_MSG CLANG_FORMAT_EXECUTABLE)

mark_as_advanced(CLANG_FORMAT_EXECUTABLE)
