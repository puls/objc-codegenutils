//
//  main.m
//  assetgen
//
//  Created by Jim Puls on 8/29/13.
//  Copyright (c) 2013 Square, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libgen.h>

#import "AGCatalogParser.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        char opt = -1;
        NSURL *searchURL = nil;
        NSString *classPrefix = @"";
        NSMutableArray *inputURLs = [NSMutableArray array];

        while ((opt = getopt(argc, (char *const*)argv, "o:f:p:h")) != -1) {
            switch (opt) {
                case 'h': {
                    printf("Usage: %s [-o <path>] [-f <path>] [-p <prefix>] [<paths>]\n", basename((char *)argv[0]));
                    printf("       %s -h\n\n", basename((char *)argv[0]));
                    printf("Options:\n");
                    printf("    -o <path>   Output files at <path>\n");
                    printf("    -f <path>   Search for *.xcassets folders starting from <path>\n");
                    printf("    -p <prefix> Use <prefix> as the class prefix in the generated code\n");
                    printf("    -h          Print this help and exit\n");
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
                if ([url.pathExtension isEqualToString:@"xcassets"]) {
                    [inputURLs addObject:url];
                }
            }
        }

        dispatch_group_t group = dispatch_group_create();

        for (NSURL *url in inputURLs) {
            dispatch_group_enter(group);
            AGCatalogParser *parser = [AGCatalogParser assetCatalogAtURL:url];
            parser.classPrefix = classPrefix;
            [parser startWithCompletionHandler:^{
                dispatch_group_leave(group);
            }];
        }

        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    }
    return 0;
}

