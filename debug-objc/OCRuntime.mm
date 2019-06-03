//
//  OCRuntime.m
//  debug-objc
//
//  Created by pillar on 2019/6/1.
//

#import "OCRuntime.h"
#import <stdint.h>
#import <objc/objc.h>
#import <stdio.h>

#if __LP64__
typedef uint32_t mask_t;  // x86_64 & arm64 asm are less efficient with 16-bits
#else
typedef uint16_t mask_t;
#endif

typedef uintptr_t cache_key_t;

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

union isa_t {
    isa_t() { }
    isa_t(uintptr_t value) : bits(value) { }
    Class cls;
    uintptr_t bits;
#if defined(ISA_BITFIELD)
    struct {
        ISA_BITFIELD;  // defined in isa.h
    };
#endif
};

struct _objc_object {
    isa_t isa;
};

struct bucket_t {
    // IMP-first is better for arm64e ptrauth and no worse for arm64.
    // SEL-first is better for armv7* and i386 and x86_64.
#if __arm64__
    void* _imp;
    cache_key_t _key;
#else
    cache_key_t _key;
    IMP _imp;
#endif
};


struct cache_t {
    struct bucket_t *_buckets;
    mask_t _mask;
    mask_t _occupied;
};

template <typename Element, typename List, uint32_t FlagMask>
struct entsize_list_tt {
    uint32_t entsizeAndFlags;
    uint32_t count;
    Element first;
};

struct method_t {
    SEL name;
    const char *types;
    IMP imp;
};

struct ivar_t {
#if __x86_64__
    // *offset was originally 64-bit on some x86_64 platforms.
    // We read and write only 32 bits of it.
    // Some metadata provides all 64 bits. This is harmless for unsigned
    // little-endian values.
    // Some code uses all 64 bits. class_addIvar() over-allocates the
    // offset for their benefit.
#endif
    int32_t *offset;
    const char *name;
    const char *type;
    // alignment is sometimes -1; use alignment() instead
    uint32_t alignment_raw;
    uint32_t size;
};

struct property_t {
    const char *name;
    const char *attributes;
};
struct method_list_t : entsize_list_tt<method_t, method_list_t, 0x3> {};
struct ivar_list_t : entsize_list_tt<ivar_t, ivar_list_t, 0> {};
struct property_list_t : entsize_list_tt<property_t, property_list_t, 0> {};

struct protocol_t : _objc_object {
    const char *mangledName;
    // tableDelegate 包含有 uiscrollViewDelegate
    struct protocol_list_t *protocols;
    method_list_t *instanceMethods;
    method_list_t *classMethods;
    method_list_t *optionalInstanceMethods;
    method_list_t *optionalClassMethods;
    property_list_t *instanceProperties;
    uint32_t size;   // sizeof(protocol_t)
    uint32_t flags;
    // Fields below this point are not always present on disk.
    const char **_extendedMethodTypes;
    const char *_demangledName;
    property_list_t *_classProperties;
};


struct _protocol_t : _objc_object {
    const char *mangledName;
    // tableDelegate 包含有 uiscrollViewDelegate
    struct protocol_list_t *protocols;
    method_list_t *instanceMethods;
    method_list_t *classMethods;
    method_list_t *optionalInstanceMethods;
    method_list_t *optionalClassMethods;
    property_list_t *instanceProperties;
    uint32_t size;   // sizeof(protocol_t)
    uint32_t flags;
    // Fields below this point are not always present on disk.
    const char **_extendedMethodTypes;
    const char *_demangledName;
    property_list_t *_classProperties;
};

typedef uintptr_t protocol_ref_t;

struct protocol_list_t {
    // count is 64-bit by accident.
    uintptr_t count;
    
    protocol_ref_t list[0]; // variable-size
    
    size_t byteSize() const {
        return sizeof(*this) + count*sizeof(list[0]);
    }
};

struct class_ro_t {
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
    const ivar_list_t * ivars;
    
    const uint8_t * weakIvarLayout;
    property_list_t *baseProperties;
    
    method_list_t *baseMethods() const {
        return baseMethodList;
    }
};
template <typename Element, typename List>
class list_array_tt {
public:
    struct array_t {
        uint32_t count;
        List* lists[0];
        
        static size_t byteSize(uint32_t count) {
            return sizeof(array_t) + count*sizeof(lists[0]);
        }
        size_t byteSize() {
            return byteSize(count);
        }
    };
    
    union {
        List* list;
        uintptr_t arrayAndFlag;
    };
    
    
    bool hasArray() const {
        return arrayAndFlag & 1;
    }
    
    array_t *array() {
        return (array_t *)(arrayAndFlag & ~1);
    }
    
    void setArray(array_t *array) {
        arrayAndFlag = (uintptr_t)array | 1;
    }
    
    uint32_t countLists() {
        if (hasArray()) {
            return array()->count;
        } else if (list) {
            return 1;
        } else {
            return 0;
        }
    }
    
    List** beginLists() {
        if (hasArray()) {
            return array()->lists;
        } else {
            return &list;
        }
    }
    
    List** endLists() {
        if (hasArray()) {
            return array()->lists + array()->count;
        } else if (list) {
            return &list + 1;
        } else {
            return &list;
        }
    }
    
};

class method_array_t :
public list_array_tt<method_t, method_list_t>
{};

class property_array_t :
public list_array_tt<property_t, property_list_t>
{};
class protocol_array_t :
public list_array_tt<protocol_ref_t, protocol_list_t>
{};

struct class_rw_t {
    // Be warned that Symbolication knows the layout of this structure.
    uint32_t flags;
    uint32_t version;
    
    const class_ro_t *ro;
    
    method_array_t methods;
    property_array_t properties;
    protocol_array_t protocols;
    
    Class firstSubclass;
    Class nextSiblingClass;
    
    char *demangledName;
    
#if SUPPORT_INDEXED_ISA
    uint32_t index;
#endif
};

struct class_data_bits_t {
    
    // Values are the FAST_ flags above.
    uintptr_t bits;
    
    class_rw_t* data() {
        return (class_rw_t *)(bits & FAST_DATA_MASK);
    }
    
};

struct _objc_class : _objc_object {
    // Class ISA;
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags
    
    class_rw_t *data() {
        return bits.data();
    }
    
};


struct swift_class_t : _objc_class {
    uint32_t flags;
    uint32_t instanceAddressOffset;
    uint32_t instanceSize;
    uint16_t instanceAlignMask;
    uint16_t reserved;
    
    uint32_t classSize;
    uint32_t classAddressOffset;
    void *description;
    // ...
    
    void *baseAddress() {
        return (void *)((uint8_t *)this - classAddressOffset);
    }
};

struct category_t {
    const char *name;
    _objc_class* cls;
    struct method_list_t *instanceMethods;
    struct method_list_t *classMethods;
    struct protocol_list_t *protocols;
    struct property_list_t *instanceProperties;
    // Fields below this point are not always present on disk.
    struct property_list_t *_classProperties;
    
    method_list_t *methodsForMeta(bool isMeta) {
        if (isMeta) return classMethods;
        else return instanceMethods;
    }
    
    property_list_t *propertiesForMeta(bool isMeta, struct header_info *hi);
};




void printInstanceMethodNames(Class aClass) {
    // 转换成 _objc_class
    _objc_class *cls = (__bridge _objc_class *)aClass;
    // 获取rw
    class_rw_t *rw = cls->bits.data();
    // methods 存的是 method_list_t *
    // 首地址
    method_list_t **method_list = rw->methods.beginLists();
    uint32_t count = rw->methods.countLists();
    for (uint32_t i = 0; i< count; i++) {
        method_list_t *methods1 = method_list[i];
        method_t *methods = &methods1->first;
        for (uint32_t j = 0;  j < methods1->count; j++) {
            method_t method = methods[j];
            printf("%s \n",(char *)method.name);   
        }
    }
}
