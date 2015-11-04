#include "../../include/freerdp/api.h"
#include <freerdp/freerdp.h>

//FREERDP_API void* csharp_instance_new(const char* host, UINT32 port, const char* username, const char* password, UINT32 width, UINT32 height);
//FREERDP_API void csharp_instance_free(void* instance);
//FREERDP_API int csharp_waitforsingleobject(void* instance);
//FREERDP_API int csharp_check_event_handles(void* instance, void* buffer);
//FREERDP_API int csharp_start(void* instance);
//FREERDP_API void csharp_stop(void* instance);
//FREERDP_API BOOL csharp_shall_disconnect(void* instance);
//FREERDP_API void csharp_disconnect(void* instance);
//FREERDP_API void csharp_set_paths(void* context, const char* home, const char* config);

FREERDP_API void* csharp_freerdp_new();
FREERDP_API void csharp_freerdp_free(void* instance);
FREERDP_API BOOL csharp_freerdp_connect(void* instance);
FREERDP_API BOOL csharp_freerdp_disconnect(void* instance);
FREERDP_API BOOL csharp_freerdp_set_connection_info(void* instance, const char* hostname, const char* username, const char* password, const char* domain,
                                                    UINT32 width, UINT32 height, UINT32 color_depth, UINT32 port, int security);
FREERDP_API BOOL csharp_freerdp_set_data_directory(void* instance, const char* directory);
FREERDP_API BOOL csharp_shall_disconnect(void* instance);
FREERDP_API BOOL csharp_waitforsingleobject(void* instance);
FREERDP_API BOOL csharp_check_event_handles(void* instance, void* buffer);
FREERDP_API void csharp_freerdp_send_input(void* instance, int keycode);
FREERDP_API void csharp_freerdp_send_cursor_event(void* instance, int x, int y, int flags);