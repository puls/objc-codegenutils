//
//  NSString+ISDAdditions.m
//  codegenutils
//
//  Created by Tony Arnold on 27/04/2014.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "NSString+ISDAdditions.h"

@implementation NSString (ISDAdditions)

- (NSString *)IDS_titlecaseString;
{
    NSArray *words = [self componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableString *output = [NSMutableString string];
    for (NSString *word in words) {
        [output appendFormat:@"%@%@", [[word substringToIndex:1] uppercaseString], [word substringFromIndex:1]];
    }
    return output;
}

@end
