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

+ (BOOL)isRuntimeHackeryMethod:(SEL)methodName;
{
    return sel_isEqual(methodName, @selector(isRuntimeHackeryMethod:)) ||
        sel_isEqual(methodName, @selector(allImageNames)) ||
        sel_isEqual(methodName, @selector(allImages));
}

+ (NSArray *)allImageNames;
{
    NSMutableArray *imageNames = [NSMutableArray array];
    unsigned int count;
    Method *methods = class_copyMethodList(object_getClass(self), &count);
    for (unsigned int index = 0; index < count; index++) {
        SEL methodName = method_getName(methods[index]);
        if ([self isRuntimeHackeryMethod:methodName]) {
            continue;
        }
        NSString *imageName = NSStringFromSelector(method_getName(methods[index]));
        // remove the "Image" suffix
        imageName = [imageName substringToIndex:[imageName length] - [@"Image" length]];
        [imageNames addObject:[imageName uppercaseString]];
    }
    free(methods);
    return imageNames;
}

+ (NSArray *)allImages;
{
    NSMutableArray *images = [NSMutableArray array];
    unsigned int count;
    Method *methods = class_copyMethodList(object_getClass(self), &count);
    for (unsigned int index = 0; index < count; index++) {
        SEL methodName = method_getName(methods[index]);
        if ([self isRuntimeHackeryMethod:methodName]) {
            continue;
        }
        id image = method_invoke(self, methods[index]);
        [images addObject:image];
    }
    free(methods);
    return images;
}

@end
