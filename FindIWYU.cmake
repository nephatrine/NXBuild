find_program(IWYU_EXECUTABLE NAMES include-what-you-use
	iwyu)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(IWYU DEFAULT_MSG IWYU_EXECUTABLE)

mark_as_advanced(IWYU_EXECUTABLE)
