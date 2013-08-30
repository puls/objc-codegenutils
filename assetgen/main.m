//
//  main.m
//  assetgen
//
//  Created by Jim Puls on 8/29/13.
//  Copyright (c) 2013 Square, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AGCatalogParser.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        dispatch_group_t group = dispatch_group_create();
        
        NSInteger index = 0;
        for (NSString *argument in [[NSProcessInfo processInfo] arguments]) {
            if (index++ == 0) {
                continue;
            }
            
            dispatch_group_enter(group);
            AGCatalogParser *parser = [AGCatalogParser assetCatalogAtURL:[NSURL fileURLWithPath:argument]];
            parser.classPrefix = @"WQ";
            [parser startWithCompletionHandler:^{
                dispatch_group_leave(group);
            }];
        }
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    }
    return 0;
}

