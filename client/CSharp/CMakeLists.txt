
set(MODULE_NAME "DevolutionsRDP")
set(MODULE_PREFIX "DEVOLUTIONSRDP")

set(${MODULE_PREFIX}_HDRS
	../../include/freerdp/api.h
	devolutionsrdp.h)

set(${MODULE_PREFIX}_SRCS
	${${MODULE_PREFIX}_HDRS}
	devolutionsrdp.c)

add_library(${MODULE_NAME} SHARED ${${MODULE_PREFIX}_SRCS})

list(APPEND ${MODULE_PREFIX}_LIBS winpr)
list(APPEND ${MODULE_PREFIX}_LIBS freerdp)

target_link_libraries(${MODULE_NAME} ${${MODULE_PREFIX}_LIBS})

set_property(TARGET ${MODULE_NAME} PROPERTY FOLDER "FreeRDP")

