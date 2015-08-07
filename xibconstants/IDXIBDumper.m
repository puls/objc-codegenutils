//
//  IDXIBDumper.m
//  codegenutils
//
//  Created by Tony Arnold on 27/04/2014.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "IDXIBDumper.h"
#import "NSString+ISDAdditions.h"

@implementation IDXIBDumper

+ (NSString *)inputFileExtension;
{
    return @"xib";
}

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;
{
    self.skipClassDeclaration = YES;
    NSString *storyboardFilename = [[self.inputURL lastPathComponent] stringByDeletingPathExtension];
    NSString *storyboardName = [storyboardFilename stringByReplacingOccurrencesOfString:@" " withString:@""];

    self.className = [NSString stringWithFormat:@"%@%@XIBIdentifiers", self.classPrefix, storyboardName];
    NSError *error = nil;
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithContentsOfURL:self.inputURL options:0 error:&error];

    NSArray *objectIdentifiers = [[document nodesForXPath:@"/document/objects//@identifier" error:&error] valueForKey:NSStringFromSelector(@selector(stringValue))];

    NSMutableArray *identifiers = [NSMutableArray arrayWithArray:objectIdentifiers];

    self.interfaceContents = [NSMutableArray array];
    self.implementationContents = [NSMutableArray array];

    NSMutableDictionary *uniqueKeys = [NSMutableDictionary dictionary];
    uniqueKeys[[NSString stringWithFormat:@"%@%@XIBName", self.classPrefix, storyboardName]] = storyboardFilename;

    for (NSString *identifier in identifiers) {
        NSString *key = [NSString stringWithFormat:@"%@%@XIB%@Identifier", self.classPrefix, storyboardName, [identifier IDS_titlecaseString]];
        uniqueKeys[key] = identifier;
    }
    for (NSString *key in [uniqueKeys keysSortedByValueUsingSelector:@selector(caseInsensitiveCompare:)]) {
        [self.interfaceContents addObject:[NSString stringWithFormat:@"extern NSString *const %@;\n", key]];
        [self.implementationContents addObject:[NSString stringWithFormat:@"NSString *const %@ = @\"%@\";\n", key, uniqueKeys[key]]];
    }

    [self writeOutputFiles];
    completionBlock();
}

@end

