/**
 * FreeRDP: A Remote Desktop Protocol Implementation
 * NTLM over HTTP
 *
 * Copyright 2012 Fujitsu Technology Solutions GmbH
 * Copyright 2012 Dmitrij Jasnov <dmitrij.jasnov@ts.fujitsu.com>
 * Copyright 2012 Marc-Andre Moreau <marcandre.moreau@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <winpr/crt.h>
#include <winpr/tchar.h>
#include <winpr/dsparse.h>

#include <openssl/rand.h>

#include "http.h"

#include "ntlm.h"

BOOL ntlm_client_init(rdpNtlm* ntlm, BOOL http, char* user, char* domain, char* password, SecPkgContext_Bindings* Bindings)
{
	SECURITY_STATUS status;

	sspi_GlobalInit();

	ntlm->http = http;
	ntlm->Bindings = Bindings;

#ifdef WITH_NATIVE_SSPI
	{
		HMODULE hSSPI;
		INIT_SECURITY_INTERFACE InitSecurityInterface;
		PSecurityFunctionTable pSecurityInterface = NULL;

		hSSPI = LoadLibrary(_T("secur32.dll"));

#ifdef UNICODE
		InitSecurityInterface = (INIT_SECURITY_INTERFACE) GetProcAddress(hSSPI, "InitSecurityInterfaceW");
#else
		InitSecurityInterface = (INIT_SECURITY_INTERFACE) GetProcAddress(hSSPI, "InitSecurityInterfaceA");
#endif
		ntlm->table = (*InitSecurityInterface)();
	}
#else
	ntlm->table = InitSecurityInterface();
#endif

	sspi_SetAuthIdentity(&(ntlm->identity), user, domain, password);

	status = ntlm->table->QuerySecurityPackageInfo(NTLMSP_NAME, &ntlm->pPackageInfo);

	if (status != SEC_E_OK)
	{
		DEBUG_WARN( "QuerySecurityPackageInfo status: 0x%08X\n", status);
		return FALSE;
	}

	ntlm->cbMaxToken = ntlm->pPackageInfo->cbMaxToken;

	status = ntlm->table->AcquireCredentialsHandle(NULL, NTLMSP_NAME,
			SECPKG_CRED_OUTBOUND, NULL, &ntlm->identity, NULL, NULL, &ntlm->credentials, &ntlm->expiration);

	if (status != SEC_E_OK)
	{
		DEBUG_WARN( "AcquireCredentialsHandle status: 0x%08X\n", status);
		return FALSE;
	}

	ntlm->haveContext = FALSE;
	ntlm->haveInputBuffer = FALSE;
	ZeroMemory(&ntlm->inputBuffer, sizeof(SecBuffer));
	ZeroMemory(&ntlm->outputBuffer, sizeof(SecBuffer));
	ZeroMemory(&ntlm->ContextSizes, sizeof(SecPkgContext_Sizes));

	ntlm->fContextReq = 0;

	if (ntlm->http)
	{
		/* flags for HTTP authentication */
		ntlm->fContextReq |= ISC_REQ_CONFIDENTIALITY;
	}
	else
	{
		/** 
		 * flags for RPC authentication:
		 * RPC_C_AUTHN_LEVEL_PKT_INTEGRITY:
		 * ISC_REQ_USE_DCE_STYLE | ISC_REQ_DELEGATE | ISC_REQ_MUTUAL_AUTH |
		 * ISC_REQ_REPLAY_DETECT | ISC_REQ_SEQUENCE_DETECT
		 */

		ntlm->fContextReq |= ISC_REQ_USE_DCE_STYLE;
		ntlm->fContextReq |= ISC_REQ_DELEGATE | ISC_REQ_MUTUAL_AUTH;
		ntlm->fContextReq |= ISC_REQ_REPLAY_DETECT | ISC_REQ_SEQUENCE_DETECT;
	}

	return TRUE;
}

BOOL ntlm_client_make_spn(rdpNtlm* ntlm, LPCTSTR ServiceClass, char* hostname)
{
	int length;
	DWORD status;
	DWORD SpnLength;
	LPTSTR hostnameX;

	length = 0;

#ifdef UNICODE
	length = strlen(hostname);
	hostnameX = (LPWSTR) malloc((length + 1)* sizeof(TCHAR));
	MultiByteToWideChar(CP_UTF8, 0, hostname, length, hostnameX, length);
	hostnameX[length] = 0;
#else
	hostnameX = hostname;
#endif

	if (!ServiceClass)
	{
		ntlm->ServicePrincipalName = (LPTSTR) _tcsdup(hostnameX);
		if (!ntlm->ServicePrincipalName)
			return FALSE;
		return TRUE;
	}

	SpnLength = 0;
	status = DsMakeSpn(ServiceClass, hostnameX, NULL, 0, NULL, &SpnLength, NULL);

	if (status != ERROR_BUFFER_OVERFLOW)
		return FALSE;

	ntlm->ServicePrincipalName = (LPTSTR) malloc(SpnLength * sizeof(TCHAR));
	if (!ntlm->ServicePrincipalName)
		return FALSE;

	status = DsMakeSpn(ServiceClass, hostnameX, NULL, 0, NULL, &SpnLength, ntlm->ServicePrincipalName);

	if (status != ERROR_SUCCESS)
		return FALSE;

	return TRUE;
}

/**
 *                                        SSPI Client Ceremony
 *
 *                                           --------------
 *                                          ( Client Begin )
 *                                           --------------
 *                                                 |
 *                                                 |
 *                                                \|/
 *                                      -----------+--------------
 *                                     | AcquireCredentialsHandle |
 *                                      --------------------------
 *                                                 |
 *                                                 |
 *                                                \|/
 *                                    -------------+--------------
 *                 +---------------> / InitializeSecurityContext /
 *                 |                 ----------------------------
 *                 |                               |
 *                 |                               |
 *                 |                              \|/
 *     ---------------------------        ---------+-------------            ----------------------
 *    / Receive blob from server /      < Received security blob? > --Yes-> / Send blob to server /
 *    -------------+-------------         -----------------------           ----------------------
 *                /|\                              |                                |
 *                 |                               No                               |
 *                Yes                             \|/                               |
 *                 |                   ------------+-----------                     |
 *                 +---------------- < Received Continue Needed > <-----------------+
 *                                     ------------------------
 *                                                 |
 *                                                 No
 *                                                \|/
 *                                           ------+-------
 *                                          (  Client End  )
 *                                           --------------
 */

BOOL ntlm_authenticate(rdpNtlm* ntlm)
{
	SECURITY_STATUS status;

	if (ntlm->outputBuffer[0].pvBuffer)
	{
		free(ntlm->outputBuffer[0].pvBuffer);
		ntlm->outputBuffer[0].pvBuffer = NULL;
	}

	ntlm->outputBufferDesc.ulVersion = SECBUFFER_VERSION;
	ntlm->outputBufferDesc.cBuffers = 1;
	ntlm->outputBufferDesc.pBuffers = ntlm->outputBuffer;
	ntlm->outputBuffer[0].BufferType = SECBUFFER_TOKEN;
	ntlm->outputBuffer[0].cbBuffer = ntlm->cbMaxToken;
	ntlm->outputBuffer[0].pvBuffer = malloc(ntlm->outputBuffer[0].cbBuffer);
	if (!ntlm->outputBuffer[0].pvBuffer)
		return FALSE;

	if (ntlm->haveInputBuffer)
	{
		ntlm->inputBufferDesc.ulVersion = SECBUFFER_VERSION;
		ntlm->inputBufferDesc.cBuffers = 1;
		ntlm->inputBufferDesc.pBuffers = ntlm->inputBuffer;
		ntlm->inputBuffer[0].BufferType = SECBUFFER_TOKEN;

		if (ntlm->Bindings)
		{
			ntlm->inputBufferDesc.cBuffers++;
			ntlm->inputBuffer[1].BufferType = SECBUFFER_CHANNEL_BINDINGS;
			ntlm->inputBuffer[1].cbBuffer = ntlm->Bindings->BindingsLength;
			ntlm->inputBuffer[1].pvBuffer = (void*) ntlm->Bindings->Bindings;
		}
	}

	if ((!ntlm) || (!ntlm->table))
	{
		DEBUG_WARN( "ntlm_authenticate: invalid ntlm context\n");
		return FALSE;
	}

	status = ntlm->table->InitializeSecurityContext(&ntlm->credentials,
			(ntlm->haveContext) ? &ntlm->context : NULL,
			(ntlm->ServicePrincipalName) ? ntlm->ServicePrincipalName : NULL,
			ntlm->fContextReq, 0, SECURITY_NATIVE_DREP,
			(ntlm->haveInputBuffer) ? &ntlm->inputBufferDesc : NULL,
			0, &ntlm->context, &ntlm->outputBufferDesc,
			&ntlm->pfContextAttr, &ntlm->expiration);

	if ((status == SEC_I_COMPLETE_AND_CONTINUE) || (status == SEC_I_COMPLETE_NEEDED) || (status == SEC_E_OK))
	{
		if (ntlm->table->CompleteAuthToken != NULL)
			ntlm->table->CompleteAuthToken(&ntlm->context, &ntlm->outputBufferDesc);

		if (ntlm->table->QueryContextAttributes(&ntlm->context, SECPKG_ATTR_SIZES, &ntlm->ContextSizes) != SEC_E_OK)
		{
			DEBUG_WARN( "QueryContextAttributes SECPKG_ATTR_SIZES failure\n");
			return FALSE;
		}

		if (status == SEC_I_COMPLETE_NEEDED)
			status = SEC_E_OK;
		else if (status == SEC_I_COMPLETE_AND_CONTINUE)
			status = SEC_I_CONTINUE_NEEDED;
	}

	if (ntlm->haveInputBuffer)
	{
		free(ntlm->inputBuffer[0].pvBuffer);
	}

	ntlm->haveInputBuffer = TRUE;
	ntlm->haveContext = TRUE;

	return (status == SEC_I_CONTINUE_NEEDED) ? TRUE : FALSE;
}

void ntlm_client_uninit(rdpNtlm* ntlm)
{
	free(ntlm->identity.User);
	free(ntlm->identity.Domain);
	free(ntlm->identity.Password);
	free(ntlm->ServicePrincipalName);

	if (ntlm->table)
	{
		ntlm->table->FreeCredentialsHandle(&ntlm->credentials);
		ntlm->table->FreeContextBuffer(ntlm->pPackageInfo);
		ntlm->table->DeleteSecurityContext(&ntlm->context);
	}
}

rdpNtlm* ntlm_new()
{
	return (rdpNtlm *)calloc(1, sizeof(rdpNtlm));
}

void ntlm_free(rdpNtlm* ntlm)
{
	if (ntlm != NULL)
	{
		free(ntlm);
	}
}
