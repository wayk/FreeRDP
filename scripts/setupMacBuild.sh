#!/bin/bash

#export OPENSSL_ROOT_DIR=external/openssl/
cmake -DCMAKE_OSX_ARCHITECTURES="i386" -DOPENSSL_INCLUDE_DIR=external/openssl/include -DOPENSSL_CRYPTO_LIBRARY=external/openssl/lib/libcrypto.a -DOPENSSL_SSL_LIBRARY=external/openssl/lib/libssl.a -DWITH_SSE2=on -DWITH_CUPS=on -G Xcode .
