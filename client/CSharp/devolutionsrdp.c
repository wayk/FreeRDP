#include "devolutionsrdp.h"
#include <freerdp/channels/channels.h>
#include <freerdp/client/channels.h>
#include <freerdp/client/cmdline.h>
#include <freerdp/gdi/gdi.h>
#include <assert.h>
#include <freerdp/log.h>

struct csharp_context
{
	rdpContext _p;
	void* buffer;
};
typedef struct csharp_context csContext;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////
//// CALLBACKS
////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static int cs_get_vk_code(int character)
{
    int _virtual_key_map[256] = {0};
    
    _virtual_key_map['0'] = VK_KEY_0;
    _virtual_key_map['1'] = VK_KEY_1;
    _virtual_key_map['2'] = VK_KEY_2;
    _virtual_key_map['3'] = VK_KEY_3;
    _virtual_key_map['4'] = VK_KEY_4;
    _virtual_key_map['5'] = VK_KEY_5;
    _virtual_key_map['6'] = VK_KEY_6;
    _virtual_key_map['7'] = VK_KEY_7;
    _virtual_key_map['8'] = VK_KEY_8;
    _virtual_key_map['9'] = VK_KEY_9;
    
    _virtual_key_map['a'] = VK_KEY_A;
    _virtual_key_map['b'] = VK_KEY_B;
    _virtual_key_map['c'] = VK_KEY_C;
    _virtual_key_map['d'] = VK_KEY_D;
    _virtual_key_map['e'] = VK_KEY_E;
    _virtual_key_map['f'] = VK_KEY_F;
    _virtual_key_map['g'] = VK_KEY_G;
    _virtual_key_map['h'] = VK_KEY_H;
    _virtual_key_map['i'] = VK_KEY_I;
    _virtual_key_map['j'] = VK_KEY_J;
    _virtual_key_map['k'] = VK_KEY_K;
    _virtual_key_map['l'] = VK_KEY_L;
    _virtual_key_map['m'] = VK_KEY_M;
    _virtual_key_map['n'] = VK_KEY_N;
    _virtual_key_map['o'] = VK_KEY_O;
    _virtual_key_map['p'] = VK_KEY_P;
    _virtual_key_map['q'] = VK_KEY_Q;
    _virtual_key_map['r'] = VK_KEY_R;
    _virtual_key_map['s'] = VK_KEY_S;
    _virtual_key_map['t'] = VK_KEY_T;
    _virtual_key_map['u'] = VK_KEY_U;
    _virtual_key_map['v'] = VK_KEY_V;
    _virtual_key_map['w'] = VK_KEY_W;
    _virtual_key_map['x'] = VK_KEY_X;
    _virtual_key_map['y'] = VK_KEY_Y;
    _virtual_key_map['z'] = VK_KEY_Z;
    
    return _virtual_key_map[character];
}

static int cs_get_unicode(int character)
{
    int _unicode_map[256] = {0};
    
    _unicode_map['-'] = 45;
    _unicode_map['/'] = 47;
    _unicode_map[':'] = 58;
    _unicode_map[';'] = 59;
    _unicode_map['('] = 40;
    _unicode_map[')'] = 41;
    _unicode_map['&'] = 38;
    _unicode_map['@'] = 64;
    _unicode_map['.'] = 46;
    _unicode_map[','] = 44;
    _unicode_map['?'] = 63;
    _unicode_map['!'] = 33;
    _unicode_map['\''] = 39;
    _unicode_map['\"'] = 34;
    
    _unicode_map['['] = 91;
    _unicode_map[']'] = 93;
    _unicode_map['{'] = 123;
    _unicode_map['}'] = 125;
    _unicode_map['#'] = 35;
    _unicode_map['%'] = 37;
    _unicode_map['^'] = 94;
    _unicode_map['*'] = 42;
    _unicode_map['+'] = 43;
    _unicode_map['='] = 61;
    
    _unicode_map['_'] = 95;
    _unicode_map['\\'] = 92;
    _unicode_map['|'] = 124;
    _unicode_map['~'] = 126;
    _unicode_map['<'] = 60;
    _unicode_map['>'] = 62;
    _unicode_map['$'] = 36;
    
    return _unicode_map[character];
}

static void cs_send_virtual_key(freerdp* instance, int vk, BOOL down)
{
    int flags;
    DWORD scancode;
    
    scancode = GetVirtualScanCodeFromVirtualKeyCode(vk, 4);
    flags = (down ? KBD_FLAGS_DOWN : KBD_FLAGS_RELEASE);
    flags |= ((scancode & KBDEXT) ? KBD_FLAGS_EXTENDED : 0);
    freerdp_input_send_keyboard_event(instance->input, flags, scancode);
}

static void cs_send_unicode_key(freerdp* instance, int vk)
{
    freerdp_input_send_unicode_keyboard_event(instance->input, 0, vk);
}

static BOOL cs_context_new(freerdp* instance, rdpContext* context)
{
	if (!(context->channels = freerdp_channels_new()))
		return FALSE;

	return TRUE;
}

static void cs_context_free(freerdp* instance, rdpContext* context)
{
	if (context && context->channels)
	{
		freerdp_channels_close(context->channels, instance);
		freerdp_channels_free(context->channels);
		context->channels = NULL;
	}
}

static BOOL cs_pre_connect(freerdp* instance)
{
	rdpSettings* settings = instance->settings;
	BOOL bitmap_cache = settings->BitmapCacheEnabled;
	settings->OrderSupport[NEG_DSTBLT_INDEX] = TRUE;
	settings->OrderSupport[NEG_PATBLT_INDEX] = TRUE;
	settings->OrderSupport[NEG_SCRBLT_INDEX] = TRUE;
	settings->OrderSupport[NEG_OPAQUE_RECT_INDEX] = TRUE;
	settings->OrderSupport[NEG_DRAWNINEGRID_INDEX] = FALSE;
	settings->OrderSupport[NEG_MULTIDSTBLT_INDEX] = FALSE;
	settings->OrderSupport[NEG_MULTIPATBLT_INDEX] = FALSE;
	settings->OrderSupport[NEG_MULTISCRBLT_INDEX] = FALSE;
	settings->OrderSupport[NEG_MULTIOPAQUERECT_INDEX] = TRUE;
	settings->OrderSupport[NEG_MULTI_DRAWNINEGRID_INDEX] = FALSE;
	settings->OrderSupport[NEG_LINETO_INDEX] = TRUE;
	settings->OrderSupport[NEG_POLYLINE_INDEX] = TRUE;
	settings->OrderSupport[NEG_MEMBLT_INDEX] = bitmap_cache;
	settings->OrderSupport[NEG_MEM3BLT_INDEX] = TRUE;
	settings->OrderSupport[NEG_MEMBLT_V2_INDEX] = bitmap_cache;
	settings->OrderSupport[NEG_MEM3BLT_V2_INDEX] = FALSE;
	settings->OrderSupport[NEG_SAVEBITMAP_INDEX] = FALSE;
	settings->OrderSupport[NEG_GLYPH_INDEX_INDEX] = TRUE;
	settings->OrderSupport[NEG_FAST_INDEX_INDEX] = TRUE;
	settings->OrderSupport[NEG_FAST_GLYPH_INDEX] = TRUE;
	settings->OrderSupport[NEG_POLYGON_SC_INDEX] = FALSE;
	settings->OrderSupport[NEG_POLYGON_CB_INDEX] = FALSE;
	settings->OrderSupport[NEG_ELLIPSE_SC_INDEX] = FALSE;
	settings->OrderSupport[NEG_ELLIPSE_CB_INDEX] = FALSE;

	settings->FrameAcknowledge = 10;

	freerdp_register_addin_provider(freerdp_channels_load_static_addin_entry, 0);
	freerdp_client_load_addins(instance->context->channels, instance->settings);

	freerdp_channels_pre_connect(instance->context->channels, instance);

	return TRUE;
}

static void copy_pixel_buffer(UINT8* dstBuf, UINT8* srcBuf, int x, int y, int width, int height, int wBuf, int hBuf, int bpp)
{
	int i;
	int length;
	int scanline;
	UINT8 *dstp, *srcp;

	length = width * bpp;
	scanline = wBuf * bpp;

	srcp = &srcBuf[(scanline * y) + (x * bpp)];
	dstp = &dstBuf[(scanline * y) + (x * bpp)];

	for (i = 0; i < height; i++)
	{
		memcpy(dstp, srcp, length);
		srcp += scanline;
		dstp += scanline;
	}
}

BOOL cs_begin_paint(rdpContext* context)
{
	rdpGdi* gdi = context->gdi;
	gdi->primary->hdc->hwnd->invalid->null = 1;
	return TRUE;
}

BOOL cs_end_paint(rdpContext* context)
{
	INT32 x, y;
	UINT32 w, h;
	rdpGdi* gdi = context->gdi;
	csContext* csc = (csContext*)context;


	x = gdi->primary->hdc->hwnd->invalid->x;
	y = gdi->primary->hdc->hwnd->invalid->y;
	w = gdi->primary->hdc->hwnd->invalid->w;
	h = gdi->primary->hdc->hwnd->invalid->h;

	if (gdi->primary->hdc->hwnd->invalid->null)
		copy_pixel_buffer(csc->buffer, gdi->primary_buffer, x, y, w, h, gdi->width, gdi->height, gdi->bytesPerPixel);

	return TRUE;
}

static BOOL cs_post_connect(freerdp* instance)
{
	UINT32 gdi_flags;
	rdpSettings *settings = instance->settings;

	assert(instance);
	assert(settings);

	if (!(instance->context->cache = cache_new(settings)))
		return FALSE;

	if (instance->settings->ColorDepth > 16)
		gdi_flags = CLRBUF_32BPP | CLRCONV_ALPHA;
	else
		gdi_flags = CLRBUF_16BPP;

	if (!gdi_init(instance, gdi_flags, NULL))
		return FALSE;

	instance->update->BeginPaint = cs_begin_paint;
	instance->update->EndPaint = cs_end_paint;

	if (freerdp_channels_post_connect(instance->context->channels, instance) < 0)
		return FALSE;

	return TRUE;
}

static void cs_post_disconnect(freerdp* instance)
{
	gdi_free(instance);
	cache_free(instance->context->cache);
}

static BOOL cs_authenticate(freerdp* instance, char** username, char** password, char** domain)
{
	return TRUE;
}

static BOOL cs_verify_certificate(freerdp* instance, char* subject, char* issuer, char* fingerprint)
{
	return TRUE;
}

static int cs_verify_x509_certificate(freerdp* instance, BYTE* data, int length, const char* hostname, int port, DWORD flags)
{
	return 1;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////
//// EXPORTED FUNCTIONS
////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void* csharp_freerdp_new()
{
	freerdp* instance;

	// create instance
	if (!(instance = freerdp_new()))
		return NULL;
	instance->PreConnect = cs_pre_connect;
	instance->PostConnect = cs_post_connect;
	instance->PostDisconnect = cs_post_disconnect;
	instance->Authenticate = cs_authenticate;
	instance->VerifyCertificate = cs_verify_certificate;
	instance->VerifyX509Certificate = cs_verify_x509_certificate;
	//instance->VerifyChangedCertificate = android_verify_changed_certificate;

	// create context
	instance->ContextSize = sizeof(csContext);
	instance->ContextNew = cs_context_new;
	instance->ContextFree = cs_context_free;

	if (!freerdp_context_new(instance))
	{
		freerdp_free(instance);
		instance = NULL;
	}

	return instance;
}

void csharp_freerdp_free(void* instance)
{
	freerdp* inst = (freerdp*)instance;

	freerdp_context_free(inst);
	freerdp_free(inst);
}

BOOL csharp_freerdp_connect(void* instance)
{
	return freerdp_connect((freerdp*)instance);
}

BOOL csharp_freerdp_disconnect(void* instance)
{
	freerdp_disconnect((freerdp*)instance);

	return TRUE;
}

BOOL csharp_freerdp_set_connection_info(void* instance, const char* hostname, const char* username, const char* password, const char* domain,
										UINT32 width, UINT32 height, UINT32 color_depth, UINT32 port, int security)
{
	freerdp* inst = (freerdp*)instance;
	rdpSettings * settings = inst->settings;

	settings->DesktopWidth = width;
	settings->DesktopHeight = height;
	settings->ColorDepth = color_depth;
	settings->ServerPort = port;
	settings->ExternalCertificateManagement = TRUE;

	// Hack for 16 bit RDVH connections:
	//   In this case we get screen corruptions when we have an odd screen resolution width ... need to investigate what is causing this...
	if (color_depth <= 16)
		settings->DesktopWidth &= (~1);

	if (!(settings->ServerHostname = strdup(hostname)))
		goto out_fail_strdup;

	if (username && strlen(username) > 0)
	{
		if (!(settings->Username = strdup(username)))
			goto out_fail_strdup;
	}

	if (password && strlen(password) > 0)
	{
		if (!(settings->Password = strdup(password)))
			goto out_fail_strdup;
		settings->AutoLogonEnabled = TRUE;
	}

	if (!(settings->Domain = strdup(domain)))
		goto out_fail_strdup;

	settings->SoftwareGdi = TRUE;
	settings->BitmapCacheV3Enabled = TRUE;

	switch (security)
	{
		case 1:
			/* Standard RDP */
			settings->RdpSecurity = TRUE;
			settings->TlsSecurity = FALSE;
			settings->NlaSecurity = FALSE;
			settings->ExtSecurity = FALSE;
			settings->UseRdpSecurityLayer = TRUE;
			break;

		case 2:
			/* TLS */
			settings->NlaSecurity = FALSE;
			settings->TlsSecurity = TRUE;
			settings->RdpSecurity = FALSE;
			settings->ExtSecurity = FALSE;
			break;

		case 3:
			/* NLA */
			settings->NlaSecurity = TRUE;
			settings->TlsSecurity = FALSE;
			settings->RdpSecurity = FALSE;
			settings->ExtSecurity = FALSE;
			break;

		default:
			break;
	}

	// set US keyboard layout
	settings->KeyboardLayout = 0x0409;

	return TRUE;

	out_fail_strdup:
	return FALSE;
}

BOOL csharp_freerdp_set_data_directory(void* instance, const char* directory)
{
	freerdp* inst = (freerdp*)instance;
	rdpSettings * settings = inst->settings;

	free(settings->HomePath);
	free(settings->ConfigPath);
	settings->HomePath = settings->ConfigPath = NULL;

	int config_dir_len = strlen(directory) + 10; /* +9 chars for /.freerdp and +1 for \0 */
	char* config_dir_buf = (char*)malloc(config_dir_len);
	if (!config_dir_buf)
		goto out_malloc_fail;

	strcpy(config_dir_buf, directory);
	strcat(config_dir_buf, "/.freerdp");
	settings->HomePath = strdup(directory);
	if (!settings->HomePath)
		goto out_strdup_fail;
	settings->ConfigPath = config_dir_buf;	/* will be freed by freerdp library */

	return TRUE;

	out_strdup_fail:
	free(config_dir_buf);
	out_malloc_fail:
	return FALSE;
}

BOOL csharp_shall_disconnect(void* instance)
{
	return freerdp_shall_disconnect((freerdp*)instance);
}

BOOL csharp_waitforsingleobject(void* instance)
{
	freerdp* inst = (freerdp*)instance;
	HANDLE handles[64];
	DWORD nCount;
	DWORD status;

	nCount = freerdp_get_event_handles(inst->context, &handles[0], 64);

	if (nCount == 0)
		return FALSE;

	status = WaitForMultipleObjects(nCount, handles, FALSE, 100);

	if (status == WAIT_FAILED)
		return FALSE;

	return TRUE;
}

BOOL csharp_check_event_handles(void* instance, void* buffer)
{
	freerdp* inst = (freerdp*)instance;
	csContext* ctxt = (csContext*)inst->context;

	int result = 0;

	ctxt->buffer = buffer;
	result = freerdp_check_event_handles(inst->context);

	return result < 0 ? FALSE : TRUE;
}

void csharp_freerdp_send_input(void* instance, int character)
{
    BOOL shift_was_sent = FALSE;
    
    if(character >= 256)
        return;
    
    int vk = cs_get_unicode(character);
    if(vk != 0)
    {
        cs_send_unicode_key((freerdp*)instance, vk);
    }
    else
    {
        if(isupper(character))
        {
            character = tolower(character);
            cs_send_virtual_key((freerdp*)instance, VK_LSHIFT, TRUE);
            shift_was_sent = TRUE;
        }
        
        vk = cs_get_vk_code(character);
        if(vk == 0)
        {
            // send as is
            vk = character;
        }
        
        // send key pressed
        cs_send_virtual_key((freerdp*)instance, vk, TRUE);
        cs_send_virtual_key((freerdp*)instance, vk, FALSE);
        
        if(shift_was_sent)
            cs_send_virtual_key((freerdp*)instance, VK_LSHIFT, FALSE);
    }
}

void csharp_freerdp_send_cursor_event(void* instance, int x, int y, int flags)
{
    freerdp_input_send_mouse_event(((freerdp*)instance)->input, flags, x, y);
}
