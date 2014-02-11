//
//  CGTAImagesCatalog+RuntimeHackery.m
//  codegenutils
//
//  Created by Jim Puls on 2/3/14.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

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
