//
//  NSObject+Runtime.mm
//  debug-objc
//
//  Created by pillar on 2019/5/30.
//

#import "NSObject+Runtime.h"
#import <objc/runtime.h>

#if __LP64__
typedef uint32_t mask_t;  // x86_64 & arm64 asm are less efficient with 16-bits
#else
typedef uint16_t mask_t;
#endif

#if !__LP64__
#define FAST_DATA_MASK 0xfffffffcUL
#else
#define FAST_DATA_MASK 0x00007ffffffffff8UL
#endif

# if __arm64__
#   define ISA_MASK        0x0000000ffffffff8ULL
#   define ISA_MAGIC_MASK  0x000003f000000001ULL
#   define ISA_MAGIC_VALUE 0x000001a000000001ULL
#   define ISA_BITFIELD                                                      \
uintptr_t nonpointer        : 1;                                       \
uintptr_t has_assoc         : 1;                                       \
uintptr_t has_cxx_dtor      : 1;                                       \
uintptr_t shiftcls          : 33; /*MACH_VM_MAX_ADDRESS 0x1000000000*/ \
uintptr_t magic             : 6;                                       \
uintptr_t weakly_referenced : 1;                                       \
uintptr_t deallocating      : 1;                                       \
uintptr_t has_sidetable_rc  : 1;                                       \
uintptr_t extra_rc          : 19
#   define RC_ONE   (1ULL<<45)
#   define RC_HALF  (1ULL<<18)

# elif __x86_64__
#   define ISA_MASK        0x00007ffffffffff8ULL
#   define ISA_MAGIC_MASK  0x001f800000000001ULL
#   define ISA_MAGIC_VALUE 0x001d800000000001ULL
#   define ISA_BITFIELD                                                        \
uintptr_t nonpointer        : 1;                                         \
uintptr_t has_assoc         : 1;                                         \
uintptr_t has_cxx_dtor      : 1;                                         \
uintptr_t shiftcls          : 44; /*MACH_VM_MAX_ADDRESS 0x7fffffe00000*/ \
uintptr_t magic             : 6;                                         \
uintptr_t weakly_referenced : 1;                                         \
uintptr_t deallocating      : 1;                                         \
uintptr_t has_sidetable_rc  : 1;                                         \
uintptr_t extra_rc          : 8
#   define RC_ONE   (1ULL<<56)
#   define RC_HALF  (1ULL<<7)
# else
#   error unknown architecture for packed isa
# endif

union _isa_t {
    _isa_t() { }
    _isa_t(uintptr_t value) : bits(value) { }
    
    Class cls;
    uintptr_t bits;
#if defined(ISA_BITFIELD)
    struct {
        ISA_BITFIELD;  // defined in isa.h
    };
#endif
};

typedef struct objc_method {
    char * sel;
    const char *method_type;
    void  *_imp;
}objc_method;

typedef struct method_list_t {
    unsigned int entsizeAndFlags;
    unsigned int count;
    objc_method first;
}method_list_t;

typedef struct property_t {
    const char *name;
    const char *attributes;
}property_t;

typedef struct property_list_t {
    unsigned int entsizeAndFlags;
    unsigned int count;
    property_t first;
}property_list_t;

typedef struct protocol_list_t {
    // count is 64-bit by accident.
    uintptr_t count;
    uintptr_t list[0]; // variable-size
}protocol_list_t;

struct ivar_t {
    int32_t *offset;
    const char *name;
    const char *type;
    // alignment is sometimes -1; use alignment() instead
    uint32_t alignment_raw;
    uint32_t size;
};

typedef struct ivar_list_t {
    unsigned int entsizeAndFlags;
    unsigned int count;
    struct ivar_t first;
}ivar_list_t;

typedef struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
#ifdef __LP64__
    uint32_t reserved;
#endif
    
    const uint8_t * ivarLayout;
    
    const char * name;
    method_list_t * baseMethodList;
    protocol_list_t * baseProtocols;
    ivar_list_t * ivars;
    
    const uint8_t * weakIvarLayout;
    property_list_t * baseProperties;
}class_ro_t;

typedef struct class_rw_t {
    // Be warned that Symbolication knows the layout of this structure.
    uint32_t flags;
    uint32_t version;
    
    const class_ro_t *ro;
    
    method_list_t * methods;
    property_list_t * properties;
    protocol_list_t * protocols;
    
    Class firstSubclass;
    Class nextSiblingClass;
    
    char * demangledName;
}class_rw_t;

struct bucket_t {
    uintptr_t _key;
    IMP _imp;
};

typedef struct cache_t {
    struct bucket_t *_buckets;
    mask_t _mask;
    mask_t _occupied;
}cache_t;

typedef struct class_data_bits_t {
    // Values are the FAST_ flags above.
    uintptr_t bits;
}class_data_bits_t;



typedef struct _objc_class{
    _isa_t isa;
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags
}_objc_class;


@implementation NSObject (Runtime)

+ (void) PrintInternalClass{
    _objc_class *objcClass = (__bridge typeof(objcClass))[self class];
    class_rw_t *classReadWrite = (typeof(classReadWrite))(objcClass->bits.bits & FAST_DATA_MASK);
    NSLog(@"兄弟，打断点来调试吧。。%@",(void*)(objcClass->isa.bits & ISA_MASK));
}
@end
