//
//  IDStoryboardDumper.m
//  codegenutils
//
//  Created by Jim Puls on 2/3/14.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "IDStoryboardDumper.h"


@interface NSString (IDStoryboardAddition)

- (NSString *)IDS_titlecaseString;

@end


@implementation IDStoryboardDumper

+ (NSString *)inputFileExtension;
{
    return @"storyboard";
}

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;
{
    self.skipClassDeclaration = YES;
    NSString *storyboardName = [[[self.inputURL lastPathComponent] stringByDeletingPathExtension]stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    self.className = [NSString stringWithFormat:@"%@%@StoryboardIdentifiers", self.classPrefix, storyboardName];
    NSError *error = nil;
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithContentsOfURL:self.inputURL options:0 error:&error];

    NSArray *storyboardIdentifiers = [[document nodesForXPath:@"//@storyboardIdentifier" error:&error] valueForKey:NSStringFromSelector(@selector(stringValue))];
    NSArray *reuseIdentifiers = [[document nodesForXPath:@"//@reuseIdentifier" error:&error] valueForKey:NSStringFromSelector(@selector(stringValue))];
    NSArray *segueIdentifiers = [[document nodesForXPath:@"//segue/@identifier" error:&error] valueForKey:NSStringFromSelector(@selector(stringValue))];
    
    NSMutableArray *identifiers = [NSMutableArray arrayWithArray:storyboardIdentifiers];
    [identifiers addObjectsFromArray:reuseIdentifiers];
    [identifiers addObjectsFromArray:segueIdentifiers];
    
    self.interfaceContents = [NSMutableArray array];
    self.implementationContents = [NSMutableArray array];
    
    NSMutableDictionary *uniqueKeys = [NSMutableDictionary dictionary];
    uniqueKeys[[NSString stringWithFormat:@"%@%@StoryboardName", self.classPrefix, storyboardName]] = storyboardName;
    
    for (NSString *identifier in identifiers) {
        NSString *key = [NSString stringWithFormat:@"%@%@Storyboard%@Identifier", self.classPrefix, storyboardName, [identifier IDS_titlecaseString]];
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


@implementation NSString (IDStoryboardAddition)

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
