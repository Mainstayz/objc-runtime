//
//  OCRuntime.m
//  debug-objc
//
//  Created by pillar on 2019/6/1.
//

#import <stdio.h>
#import "OCRuntime.h"

void printInstanceMethodNames(_objc_class *cls) {
    class_rw_t *rw = cls->bits.data();
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
