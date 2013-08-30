//
//  AGCatalogParser.m
//  assetgen
//
//  Created by Jim Puls on 8/29/13.
//  Copyright (c) 2013 Square, Inc. All rights reserved.
//

#import "AGCatalogParser.h"

@interface AGCatalogParser ()

@property (copy) NSURL *rootURL;
@property (strong) NSArray *imageSetURLs;
@property (copy) NSString *catalogName;

@property (strong) NSMutableArray *interfaceContents;
@property (strong) NSMutableArray *implementationContents;

@end


@implementation AGCatalogParser

+ (instancetype)assetCatalogAtURL:(NSURL *)url;
{
    AGCatalogParser *parser = [self new];
    
    parser.rootURL = url;
    parser.catalogName = [url.lastPathComponent stringByDeletingPathExtension];
    parser.classPrefix = @"";
    
    return parser;
}

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;
{
    dispatch_group_t dispatchGroup = dispatch_group_create();
    dispatch_queue_t dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_queue_t returnQueue = dispatch_get_current_queue();
    dispatch_async(dispatchQueue, ^{
        [self findImageSetURLs];

        self.interfaceContents = [NSMutableArray array];
        self.implementationContents = [NSMutableArray array];
        
        for (NSURL *imageSetURL in self.imageSetURLs) {
            dispatch_group_async(dispatchGroup, dispatchQueue, ^{
                [self parseImageSetAtURL:imageSetURL];
            });
        }
        
        dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
        
        [self outputCode];
        
        dispatch_async(returnQueue, completionBlock);
    });
}

- (void)findImageSetURLs;
{
    NSMutableArray *imageSetURLs = [NSMutableArray array];
    NSDirectoryEnumerator *enumerator = [[NSFileManager new] enumeratorAtURL:self.rootURL includingPropertiesForKeys:@[NSURLNameKey] options:0 errorHandler:NULL];
    for (NSURL *url in enumerator) {
        if ([url.pathExtension isEqualToString:@"imageset"]) {
            [imageSetURLs addObject:url];
        }
    }
    self.imageSetURLs = [imageSetURLs copy];
}

- (void)parseImageSetAtURL:(NSURL *)url;
{
    NSString *name = [[[url lastPathComponent] stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"~" withString:@"_"];
    NSURL *contentsURL = [url URLByAppendingPathComponent:@"Contents.json"];
    NSData *contentsData = [NSData dataWithContentsOfURL:contentsURL options:NSDataReadingMappedIfSafe error:NULL];
    if (!contentsData) {
        return;
    }
    
    NSDictionary *contents = [NSJSONSerialization JSONObjectWithData:contentsData options:0 error:NULL];
    if (!contents) {
        return;
    }
    
    NSUInteger resizableIndex = [[contents[@"images"] valueForKey:@"resizing"] indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return obj != [NSNull null];
    }];
    
    if (resizableIndex == NSNotFound) {
        return;
    }
    
    NSString *interface = [NSString stringWithFormat:@"+ (UIImage *)imageFor%@;\n", name];
    @synchronized(self.interfaceContents) {
        [self.interfaceContents addObject:interface];
    }
    
    NSMutableString *implementation = [interface mutableCopy];
    [implementation appendString:@"{\n"];
    
    [implementation appendFormat:@"    UIImage *cachedImage = [[self imageCache] objectForKey:@\"%@\"];\n", name];
    [implementation appendString:@"    if (cachedImage) {\n"];
    [implementation appendString:@"        return cachedImage;\n"];
    [implementation appendString:@"    }\n\n"];
    
    for (NSDictionary *variant in contents[@"images"]) {
        BOOL isUniversal = [variant[@"idiom"] isEqualToString:@"universal"];
        NSString *indentation = @"";
        if (!isUniversal) {
            NSString *idiom = [variant[@"idiom"] isEqualToString:@"iphone"] ? @"UIUserInterfaceIdiomPhone" : @"UIUserInterfaceIdiomPad";
            [implementation appendFormat:@"    if (UI_USER_INTERFACE_IDIOM() == %@) {\n", idiom];
            indentation = @"    ";
        }
        
        CGFloat scale = [variant[@"scale"] floatValue];
        NSString *filename = [variant[@"filename"] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"@%@", variant[@"scale"]] withString:@""];
        [implementation appendFormat:@"%@    if ([UIScreen mainScreen].scale == %.1ff) {\n", indentation, scale];
        [implementation appendFormat:@"%@        UIImage *baseImage = [UIImage imageNamed:@\"%@\"];\n", indentation, filename];

        CGFloat top = [variant[@"resizing"][@"capInsets"][@"top"] floatValue] / scale;
        CGFloat left = [variant[@"resizing"][@"capInsets"][@"left"] floatValue] / scale;
        CGFloat bottom = [variant[@"resizing"][@"capInsets"][@"bottom"] floatValue] / scale;
        CGFloat right = [variant[@"resizing"][@"capInsets"][@"right"] floatValue] / scale;
        NSString *mode = [variant[@"resizing"][@"center"][@"mode"] isEqualToString:@"stretch"] ? @"UIImageResizingModeStretch" : @"UIImageResizingModeTile";
        
        [implementation appendFormat:@"%@        return [baseImage resizableImageWithCapInsets:UIEdgeInsetsMake(%.1ff, %.1ff, %.1ff, %.1ff) resizingMode:%@];\n", indentation, top, left, bottom, right, mode];

        [implementation appendFormat:@"%@    }\n", indentation];
        
        if (!isUniversal) {
            [implementation appendString:@"    }\n"];
        }
    }
    
    [implementation appendString:@"    return nil;\n"];
    [implementation appendString:@"}\n"];
    @synchronized(self.implementationContents) {
        [self.implementationContents addObject:implementation];
    }
}

- (NSString *)cacheMethodContents;
{
    NSMutableString *contents = [NSMutableString string];
    
    [contents appendString:@"+ (NSCache *)imageCache;\n"];
    [contents appendString:@"{\n"];
    [contents appendString:@"    static dispatch_once_t onceToken;\n"];
    [contents appendString:@"    static NSCache *imageCache = nil;\n"];
    [contents appendString:@"    dispatch_once(&onceToken, ^{\n"];
    [contents appendString:@"        imageCache = [NSCache new];\n"];
    [contents appendString:@"    });\n"];
    [contents appendString:@"    return imageCache;\n"];
    [contents appendString:@"}\n"];
    
    return contents;
}

- (void)outputCode;
{
    NSURL *currentDirectory = [NSURL fileURLWithPath:[[NSFileManager new] currentDirectoryPath]];
    NSString *className = [NSString stringWithFormat:@"%@%@Catalog", self.classPrefix, self.catalogName];
    NSString *classNameH = [className stringByAppendingPathExtension:@"h"];
    NSString *classNameM = [className stringByAppendingPathExtension:@"m"];
    
    [self.interfaceContents sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
    [self.implementationContents sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
    
    NSString *interface = [NSString stringWithFormat:@"//\n// This file is generated by objc-assetgen. Please do not edit.\n//\n\n#import <UIKit/UIKit.h>\n\n@interface %@ : NSObject\n\n%@\n@end\n", className, [self.interfaceContents componentsJoinedByString:@""]];
    
    [interface writeToURL:[currentDirectory URLByAppendingPathComponent:classNameH] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    
    NSString *implementation = [NSString stringWithFormat:@"//\n// This file is generated by objc-assetgen. Please do not edit.\n//\n\n#import \"%@\"\n\n@implementation %@\n\n%@\n%@\n\n@end\n", classNameH, className, self.cacheMethodContents, [self.implementationContents componentsJoinedByString:@"\n"]];
    
    [implementation writeToURL:[currentDirectory URLByAppendingPathComponent:classNameM] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    
    NSLog(@"Wrote %@ to %@", className, currentDirectory);
}

@end
