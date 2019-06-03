//
//  main.m
//  debug-objc
//
//  Created by Closure on 2018/12/4.
//

#import <Foundation/Foundation.h>
#import "OCRuntime.h"
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

@interface Foo (xx)

@end

@implementation Foo (xx)

- (void)xxxxx {
    
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Class cls = [Foo class];
        printInstanceMethodNames(cls);
    }
    return 0;
}
