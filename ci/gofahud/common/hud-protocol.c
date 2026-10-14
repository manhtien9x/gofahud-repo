#include "hud-protocol.h"
#include <string.h>
static bool Varint(const uint8_t *p,size_t n,size_t *i,uint64_t *v) {
    *v=0;
    for(unsigned shift=0;shift<70;shift+=7) {
        if(*i>=n) return false;
        uint8_t b=p[(*i)++];
        if(shift==63 && (b&0xfe)) return false;
        *v|=(uint64_t)(b&127)<<shift;
        if(!(b&128)) return true;
    }
    return false;
}
static bool Decode(const uint8_t *p,size_t n,uint32_t *fields,unsigned count) {
    if((!p && n) || n>16384) return false;
    memset(fields,0,count*sizeof(*fields));
    size_t i=0;
    while(i<n) {
        uint64_t tag=0,value=0;
        if(!Varint(p,n,&i,&tag) || !(tag>>3) || (tag>>3)>0x1fffffff) return false;
        uint64_t field=tag>>3; unsigned wire=tag&7;
        if(field<=count && wire!=0) return false;
        switch(wire) {
            case 0:
                if(!Varint(p,n,&i,&value)) return false;
                if(field<=count) { if(value>UINT32_MAX) return false; fields[field-1]=(uint32_t)value; }
                break;
            case 1: if(n-i<8) return false; i+=8; break;
            case 2: if(!Varint(p,n,&i,&value) || value>n-i) return false; i+=(size_t)value; break;
            case 5: if(n-i<4) return false; i+=4; break;
            default: return false;
        }
    }
    return true;
}
bool GOFAHUDDecodeSigns(const uint8_t *p,size_t n,GOFAHUDSigns *out) {
    uint32_t f[5];
    if(!out || !Decode(p,n,f,5)) return false;
    *out=(GOFAHUDSigns){f[0],f[1],f[2],f[3],f[4]}; return true;
}
bool GOFAHUDDecodeSpeed(const uint8_t *p,size_t n,uint32_t *out) {
    uint32_t f[1];
    if(!out || !Decode(p,n,f,1) || f[0]>400) return false;
    *out=f[0]; return true;
}
uint32_t GOFAHUDLimit(uint32_t sign) { return sign>=3 && sign<=10 ? sign*10 : sign==11 ? 120 : 0; }
bool GOFAHUDIsCamera(uint32_t sign) { return sign==32 || sign==33 || sign==34 || sign==36; }
