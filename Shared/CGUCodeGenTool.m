//
//  CGCodeGenTool.m
//  codegenutils
//
//  Created by Jim Puls on 9/6/13.
//  Copyright (c) 2013 Square, Inc. All rights reserved.
//

#import "CGUCodeGenTool.h"

#import <libgen.h>

@interface CGUCodeGenTool ()

@property (copy) NSString *toolName;

@end


@implementation CGUCodeGenTool

+ (NSString *)inputFileExtension;
{
    NSAssert(NO, @"Unimplemented abstract method: %@", NSStringFromSelector(_cmd));
    return nil;
}

+ (int)startWithArgc:(int)argc argv:(const char **)argv;
{
    char opt = -1;
    NSURL *searchURL = nil;
    NSString *classPrefix = @"";
    BOOL target6 = NO;
    NSMutableArray *inputURLs = [NSMutableArray array];
    
    while ((opt = getopt(argc, (char *const*)argv, "o:f:p:h6")) != -1) {
        switch (opt) {
            case 'h': {
                printf("Usage: %s [-6] [-o <path>] [-f <path>] [-p <prefix>] [<paths>]\n", basename((char *)argv[0]));
                printf("       %s -h\n\n", basename((char *)argv[0]));
                printf("Options:\n");
                printf("    -o <path>   Output files at <path>\n");
                printf("    -f <path>   Search for *.%s folders starting from <path>\n", [[self inputFileExtension] UTF8String]);
                printf("    -p <prefix> Use <prefix> as the class prefix in the generated code\n");
                printf("    -h          Print this help and exit\n");
                printf("    -6          Target iOS 6 in addition to iOS 7\n");
                printf("    <paths>     Input files; this and/or -f are required.\n");
                return 0;
            }
                
            case 'o': {
                NSString *outputPath = [[NSString alloc] initWithUTF8String:optarg];
                outputPath = [outputPath stringByExpandingTildeInPath];
                [[NSFileManager defaultManager] changeCurrentDirectoryPath:outputPath];
                break;
            }
                
            case 'f': {
                NSString *searchPath = [[NSString alloc] initWithUTF8String:optarg];
                searchPath = [searchPath stringByExpandingTildeInPath];
                searchURL = [NSURL fileURLWithPath:searchPath];
                break;
            }
                
            case 'p': {
                classPrefix = [[NSString alloc] initWithUTF8String:optarg];
                break;
            }
                
            case '6': {
                target6 = YES;
                break;
            }
                
            default:
                break;
        }
    }
    
    for (int index = optind; index < argc; index++) {
        NSString *inputPath = [[NSString alloc] initWithUTF8String:argv[index]];
        inputPath = [inputPath stringByExpandingTildeInPath];
        [inputURLs addObject:[NSURL fileURLWithPath:inputPath]];
    }
    
    if (searchURL) {
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:searchURL includingPropertiesForKeys:@[NSURLNameKey] options:0 errorHandler:NULL];
        for (NSURL *url in enumerator) {
            if ([url.pathExtension isEqualToString:[self inputFileExtension]]) {
                [inputURLs addObject:url];
            }
        }
    }
    
    dispatch_group_t group = dispatch_group_create();
    
    for (NSURL *url in inputURLs) {
        dispatch_group_enter(group);
        
        CGUCodeGenTool *target = [self new];
        target.inputURL = url;
        target.targetiOS6 = target6;
        target.classPrefix = classPrefix;
        target.toolName = [[NSString stringWithUTF8String:argv[0]] lastPathComponent];
        [target startWithCompletionHandler:^{
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    return 0;
}

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;
{
    NSAssert(NO, @"Unimplemented abstract method: %@", NSStringFromSelector(_cmd));
}

- (void)writeOutputFiles;
{
    NSAssert(self.className, @"Class name isn't set");

    NSString *classNameH = [self.className stringByAppendingPathExtension:@"h"];
    NSString *classNameM = [self.className stringByAppendingPathExtension:@"m"];

    NSURL *currentDirectory = [NSURL fileURLWithPath:[[NSFileManager new] currentDirectoryPath]];
    NSURL *interfaceURL = [currentDirectory URLByAppendingPathComponent:classNameH];
    NSURL *implementationURL = [currentDirectory URLByAppendingPathComponent:classNameM];
    
    [self.interfaceContents sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
    [self.implementationContents sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
    
    NSMutableString *interface = [NSMutableString stringWithFormat:@"//\n// This file is generated from %@ by %@.\n// Please do not edit.\n//\n\n#import <UIKit/UIKit.h>\n\n\n", self.inputURL.lastPathComponent, self.toolName];

    if (self.skipClassDeclaration) {
        [interface appendString:[self.interfaceContents componentsJoinedByString:@""]];
    } else {
        [interface appendFormat:@"@interface %@ : NSObject\n\n%@\n@end\n", self.className, [self.interfaceContents componentsJoinedByString:@""]];
    }
    
    if (![interface isEqualToString:[NSString stringWithContentsOfURL:interfaceURL encoding:NSUTF8StringEncoding error:NULL]]) {
        [interface writeToURL:interfaceURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    
    NSMutableString *implementation = [NSMutableString stringWithFormat:@"//\n// This file is generated from %@ by %@.\n// Please do not edit.\n//\n\n#import \"%@\"\n\n\n", self.inputURL.lastPathComponent, self.toolName, classNameH];
    if (self.skipClassDeclaration) {
        [implementation appendString:[self.implementationContents componentsJoinedByString:@""]];
    } else {
        [implementation appendFormat:@"@implementation %@\n\n%@\n@end\n", self.className, [self.implementationContents componentsJoinedByString:@"\n"]];
    }

    if (![implementation isEqualToString:[NSString stringWithContentsOfURL:implementationURL encoding:NSUTF8StringEncoding error:NULL]]) {
        [implementation writeToURL:implementationURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    
    NSLog(@"Wrote %@ to %@", self.className, currentDirectory);
}

- (NSString *)methodNameForKey:(NSString *)key;
{
    NSMutableString *mutableKey = [key mutableCopy];
    // If the string is already all caps, it's an abbrevation. Lowercase the whole thing.
    // Otherwise, camelcase it by lowercasing the first character.
    if ([mutableKey isEqualToString:[mutableKey uppercaseString]]) {
        mutableKey = [[mutableKey lowercaseString] mutableCopy];
    } else {
        [mutableKey replaceCharactersInRange:NSMakeRange(0, 1) withString:[[key substringToIndex:1] lowercaseString]];
    }
    [mutableKey replaceOccurrencesOfString:@" " withString:@"" options:0 range:NSMakeRange(0, mutableKey.length)];
    [mutableKey replaceOccurrencesOfString:@"~" withString:@"" options:0 range:NSMakeRange(0, mutableKey.length)];
    return [mutableKey copy];
}

@end
