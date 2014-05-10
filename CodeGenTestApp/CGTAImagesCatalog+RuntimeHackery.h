//
//  CGTAImagesCatalog+RuntimeHackery.h
//  codegenutils
//
//  Created by Jim Puls on 2/3/14.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "CGTAImagesCatalog.h"

@interface CGTAImagesCatalog (RuntimeHackery)

+ (NSArray *)allImageNames;
+ (NSArray *)allImages;

@end
