#include "../../include/freerdp/api.h"
#include <freerdp/freerdp.h>

FREERDP_API void* csharp_freerdp_new();
FREERDP_API void csharp_freerdp_free(void* instance);
FREERDP_API BOOL csharp_freerdp_connect(void* instance);
FREERDP_API BOOL csharp_freerdp_disconnect(void* instance);
FREERDP_API BOOL csharp_freerdp_set_connection_info(void* instance, const char* hostname, const char* username, const char* password, const char* domain,
                                                    UINT32 width, UINT32 height, UINT32 color_depth, UINT32 port, int security);
FREERDP_API BOOL csharp_freerdp_set_gateway_settings(void* instance, const char* hostname, UINT32 port, const char* username, const char* password, const char* domain, BOOL bypassLocal);
FREERDP_API BOOL csharp_freerdp_set_data_directory(void* instance, const char* directory);
FREERDP_API BOOL csharp_shall_disconnect(void* instance);
FREERDP_API BOOL csharp_waitforsingleobject(void* instance);
FREERDP_API BOOL csharp_check_event_handles(void* instance, void* buffer);
FREERDP_API void csharp_freerdp_send_unicode(void* instance, int character);
FREERDP_API void csharp_freerdp_send_vkcode(void* instance, int vkcode, BOOL down);
FREERDP_API void csharp_freerdp_send_input(void* instance, int keycode, BOOL down);
FREERDP_API void csharp_freerdp_send_cursor_event(void* instance, int x, int y, int flags);
FREERDP_API UINT16 csharp_get_update_rect_x(void* instance);
FREERDP_API UINT16 csharp_get_update_rect_y(void* instance);
FREERDP_API UINT16 csharp_get_update_rect_width(void* instance);
FREERDP_API UINT16 csharp_get_update_rect_height(void* instance);
FREERDP_API BOOL csharp_get_is_buffer_updated(void* instance);
FREERDP_API void csharp_set_log_output(const char* path, const char* name);