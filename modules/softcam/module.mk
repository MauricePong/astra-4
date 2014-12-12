
FFDECSA=1

if echo "$APP_CFLAGS" | grep -q "\-DFFDECSA=0" ; then
    FFDECSA=0
fi

if [ $FFDECSA -ne 1 -a $LIBDVBCSA -ne 1 ] ; then
    ERROR="DVB-CSA is not found"
fi

SOURCES_CSA=""

if [ $FFDECSA -eq 1 ] ; then
    SOURCES_CSA="FFdecsa/FFdecsa.c"
    CFLAGS="-DFFDECSA=1"
elif [ $LIBDVBCSA -eq 1 ]; then
    CFLAGS="-DLIBDVBCSA=1"
fi

SOURCES_CAM="cam/cam.c"
SOURCES_CAS="cas/irdeto.c cas/viaccess.c cas/dre.c cas/conax.c cas/nagra.c cas/videoguard.c cas/mediaguard.c cas/cryptoworks.c cas/bulcrypt.c cas/exset.c cas/griffin.c"

MODULES="decrypt"

libssl_test_c()
{
    cat <<EOF
#include <stdio.h>
#include <openssl/des.h>
int main(void) { DES_cblock b; DES_random_key((DES_cblock *)b); return 0; }
EOF
}

check_libssl()
{
    libssl_test_c | $APP_C -Werror $APP_CFLAGS -o .link-test $APP_LDFLAGS $1 -x c - >/dev/null 2>&1
    if [ $? -eq 0 ] ; then
        rm -f .link-test
        return 0
    else
        return 1
    fi
}

check_libssl_all()
{
    if check_libssl ; then
        SOURCES_CAM="$SOURCES_CAM cam/newcamd.c"
        MODULES="$MODULES newcamd"
        return 0
    fi

    if check_libssl "-lcrypto" ; then
        LDFLAGS="-lcrypto"
        SOURCES_CAM="$SOURCES_CAM cam/newcamd.c"
        MODULES="$MODULES newcamd"
        return 0
    fi

    echo "$MODULE: warning: libssl-dev is not found. newcamd disabled" >&2
    return 1
}

check_libssl_all

SOURCES="$SOURCES_CSA $SOURCES_CAM $SOURCES_CAS decrypt.c"

# SSE2

sse2_test_c()
{
    cat <<EOF
#include <stdio.h>
#include <emmintrin.h>
int main(void) { return 0; }
EOF
}

check_sse2()
{
    sse2_test_c | $APP_C -Werror $CFLAGS $APP_CFLAGS -o .link-test -x c - >/dev/null 2>&1
    if [ $? -eq 0 ] ; then
        rm -f .link-test
        return 0
    else
        return 1
    fi
}

if [ $FFDECSA -eq 1 ] ; then
    if check_sse2 ; then
        CFLAGS="$CFLAGS -DPARALLEL_MODE=1286"
    else
        echo "$MODULE: warning: SSE2 is not found" >&2
        CFLAGS="$CFLAGS -DPARALLEL_MODE=642"
    fi
fi
