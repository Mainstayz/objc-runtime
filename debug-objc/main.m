//
//  main.m
//  debug-objc
//
//  Created by Closure on 2018/12/4.
//

#import <Foundation/Foundation.h>

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
        Foo *f = [Foo new];
        [f hello];
        [f hello];
        
    }
    return 0;
}
