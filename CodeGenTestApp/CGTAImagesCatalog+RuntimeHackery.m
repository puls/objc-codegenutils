//
//  CGTAImagesCatalog+RuntimeHackery.m
//  codegenutils
//
//  Created by Jim Puls on 2/3/14.
//  Copyright (c) 2014 Square, Inc. All rights reserved.
//

#import "CGTAImagesCatalog+RuntimeHackery.h"

#import <objc/runtime.h>
#import <objc/message.h>


@implementation CGTAImagesCatalog (RuntimeHackery)

+ (NSArray *)allImages;
{
    NSMutableArray *images = [NSMutableArray array];
    unsigned int count;
    Method *methods = class_copyMethodList(object_getClass(self), &count);
    for (unsigned int index = 0; index < count; index++) {
        if (sel_isEqual(method_getName(methods[index]), _cmd)) {
            continue;
        }
        id image = method_invoke(self, methods[index]);
        [images addObject:image];
    }
    free(methods);
    return images;
}

@end
