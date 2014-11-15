project(MacFreeRDP)

set(MODULE_NAME "MacFreeRDP-headless")
set(MODULE_OUTPUT_NAME "MacFreeRDP-headless")
set(MODULE_PREFIX "FREERDP_CLIENT_MAC_CLIENT")

# Import libraries
find_library(FOUNDATION_LIBRARY Foundation)
find_library(COCOA_LIBRARY Cocoa)

set(MACOSX_BUNDLE_INFO_STRING "MacFreeRDP")
set(MACOSX_BUNDLE_GUI_IDENTIFIER "com.freerdp.mac")
set(MACOSX_BUNDLE_BUNDLE_IDENTIFIER "FreeRDP-headless.Mac")
set(MACOSX_BUNDLE_LONG_VERSION_STRING "MacFreeRDP Headless Client Version 1.0.0")
set(MACOSX_BUNDLE_BUNDLE_NAME "MacFreeRDP-headless")
set(MACOSX_BUNDLE_SHORT_VERSION_STRING 1.0.0)
set(MACOSX_BUNDLE_BUNDLE_VERSION 1.0.0)
set(MACOSX_BUNDLE_COPYRIGHT "Copyright 2014. All Rights Reserved.")

set(MACOSX_BUNDLE_NSPRINCIPAL_CLASS "NSApplication")
set(MACOSX_BUNDLE_BACKGROUNDONLY "true")

mark_as_advanced(COCOA_LIBRARY FOUNDATION_LIBRARY)
set(APP_TYPE MACOSX_BUNDLE)

set(${MODULE_PREFIX}_SOURCES "")

set(${MODULE_PREFIX}_OBJECTIVE_SOURCES
	main.m
	AppDelegate.m
    MRDPIPCClient.m)

list(APPEND ${MODULE_PREFIX}_SOURCES ${${MODULE_PREFIX}_OBJECTIVE_SOURCES})

set(${MODULE_PREFIX}_HEADERS
	AppDelegate.h
    MRDPIPCClient.h
    MRDPIPCServer.h)

add_executable(${MODULE_NAME}
	${APP_TYPE} 
	${${MODULE_PREFIX}_HEADERS}
	${${MODULE_PREFIX}_SOURCES}
	${${MODULE_PREFIX}_RESOURCES})

set_target_properties(${MODULE_NAME} PROPERTIES OUTPUT_NAME "${MODULE_OUTPUT_NAME}") 

# Tell the compiler where to look for the FreeRDP framework
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -F../")

# Tell XCode where to look for the MacFreeRDP framework
set_target_properties(${MODULE_NAME} PROPERTIES XCODE_ATTRIBUTE_FRAMEWORK_SEARCH_PATHS
	"${XCODE_ATTRIBUTE_FRAMEWORK_SEARCH_PATHS} ${CMAKE_CURRENT_BINARY_DIR}/../$(CONFIGURATION)")

# Set the info plist to the custom instance
#set_target_properties(${MODULE_NAME} PROPERTIES MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_BINARY_DIR}/Info.plist)

# Disable transitive linking
target_link_libraries(${MODULE_NAME} ${COCOA_LIBRARY} ${FOUNDATION_LIBRARY} MacFreeRDP-library)

set_property(TARGET ${MODULE_NAME} PROPERTY FOLDER "Client/Mac")

# Embed the FreeRDP framework into the app bundle
add_custom_command(TARGET ${MODULE_NAME} POST_BUILD
	COMMAND mkdir ARGS -p ${CMAKE_CURRENT_BINARY_DIR}/$(CONFIGURATION)/${MODULE_OUTPUT_NAME}.app/Contents/Frameworks
	COMMAND ditto ${CMAKE_CURRENT_BINARY_DIR}/../$(CONFIGURATION)/MacFreeRDP.framework ${CMAKE_CURRENT_BINARY_DIR}/$(CONFIGURATION)/${MODULE_OUTPUT_NAME}.app/Contents/Frameworks/MacFreeRDP.framework
	COMMAND install_name_tool -change "@executable_path/../Frameworks/MacFreeRDP.framework/Versions/${MAC_OS_X_BUNDLE_BUNDLE_VERSION}/MacFreeRDP"
		"@executable_path/../Frameworks/MacFreeRDP.framework/Versions/Current/MacFreeRDP"
		"${CMAKE_CURRENT_BINARY_DIR}/$(CONFIGURATION)/${MODULE_OUTPUT_NAME}.app/Contents/MacOS/${MODULE_NAME}"
	COMMENT Setting install name for MacFreeRDP)