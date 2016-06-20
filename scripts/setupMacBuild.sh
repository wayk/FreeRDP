#!/bin/bash

export OPENSSL_ROOT_DIR=external/openssl/
cmake -DCMAKE_OSX_ARCHITECTURES="i386" -DWITH_SSE2=on -DWITH_CUPS=on -G Xcode .
