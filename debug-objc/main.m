//
//  main.m
//  debug-objc
//
//  Created by Closure on 2018/12/4.
//

#import <Foundation/Foundation.h>
@interface Dog : NSObject
- (void)run;
@end
@implementation Dog

- (void)run {
    NSLog(@"run");
}

@end

@interface Foo : NSObject
- (void)hello;
@end
@implementation Foo
- (void)hello {
    printf("你好\n");
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        Foo *f = [Foo alloc];
        [f hello];
        [f hello];
        void (^testblock)(void) = ^(){
            NSLog(@"Hello world!");
        };
        
        
        
//        if (!obj) return nil;
//        obj->initInstanceIsa(cls, hasCxxDtor);

        
    }
    return 0;
}
