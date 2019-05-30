//
//  main.m
//  debug-objc
//
//  Created by Closure on 2018/12/4.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "NSObject+Runtime.h"
@interface Dog : NSObject
- (void)run;
@end
@implementation Dog
- (void)run {
    NSLog(@"run");
}
@end
@interface Foo : Dog
@property (nonatomic, copy, readonly) NSString *name;
- (void)hello;
@end
@implementation Foo
- (void)hello {
    printf("你好\n");
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        [Foo PrintInternalClass];
    }
    return 0;
}
