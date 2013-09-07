//
//  AGCatalogParser.m
//  assetgen
//
//  Created by Jim Puls on 8/29/13.
//  Copyright (c) 2013 Square, Inc. All rights reserved.
//

#import "AGCatalogParser.h"

@interface AGCatalogParser ()

@property (strong) NSArray *imageSetURLs;

@end


@implementation AGCatalogParser

+ (NSString *)inputFileExtension;
{
    return @"xcassets";
}

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;
{
    dispatch_group_t dispatchGroup = dispatch_group_create();
    dispatch_queue_t dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(dispatchQueue, ^{
        [self findImageSetURLs];

        self.interfaceContents = [NSMutableArray array];
        self.implementationContents = [NSMutableArray array];
        
        self.className = [NSString stringWithFormat:@"%@%@Catalog", self.classPrefix, [[self.inputURL lastPathComponent] stringByDeletingPathExtension]];
        
        for (NSURL *imageSetURL in self.imageSetURLs) {
            dispatch_group_async(dispatchGroup, dispatchQueue, ^{
                [self parseImageSetAtURL:imageSetURL];
            });
        }
        
        dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
        
        [self writeOutputFiles];
        
        completionBlock();
    });
}

- (void)findImageSetURLs;
{
    NSMutableArray *imageSetURLs = [NSMutableArray array];
    NSDirectoryEnumerator *enumerator = [[NSFileManager new] enumeratorAtURL:self.inputURL includingPropertiesForKeys:@[NSURLNameKey] options:0 errorHandler:NULL];
    for (NSURL *url in enumerator) {
        if ([url.pathExtension isEqualToString:@"imageset"]) {
            [imageSetURLs addObject:url];
        }
    }
    self.imageSetURLs = [imageSetURLs copy];
}

- (void)parseImageSetAtURL:(NSURL *)url;
{
    NSString *methodName = [self methodNameForKey:[[url lastPathComponent] stringByDeletingPathExtension]];
    NSURL *contentsURL = [url URLByAppendingPathComponent:@"Contents.json"];
    NSData *contentsData = [NSData dataWithContentsOfURL:contentsURL options:NSDataReadingMappedIfSafe error:NULL];
    if (!contentsData) {
        return;
    }
    
    NSDictionary *contents = [NSJSONSerialization JSONObjectWithData:contentsData options:0 error:NULL];
    if (!contents) {
        return;
    }

    // Sort the variants: retina4 comes first, then iphone/ipad-specific, then universal
    // Within each group, 2x comes before 1x
    NSArray *variants = [contents[@"images"] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        if (![obj1[@"subtype"] isEqualToString:obj2[@"subtype"]]) {
            if (obj1[@"subtype"]) {
                return NSOrderedAscending;
            }
            if (obj2[@"subtype"]) {
                return NSOrderedDescending;
            }
        }
        
        if (![obj1[@"idiom"] isEqualToString:obj2[@"idiom"]]) {
            if ([obj1[@"idiom"] isEqualToString:@"universal"]) {
                return NSOrderedDescending;
            }
            if ([obj2[@"idiom"] isEqualToString:@"universal"]) {
                return NSOrderedAscending;
            }
        }
        
        return -[obj1[@"scale"] compare:obj2[@"scale"]];
    }];

    NSString *interface = [NSString stringWithFormat:@"+ (UIImage *)%@Image;\n", methodName];
    @synchronized(self.interfaceContents) {
        [self.interfaceContents addObject:interface];
    }
    
    NSMutableString *implementation = [interface mutableCopy];
    [implementation appendString:@"{\n"];
    
    // If there are only one or two variants and they only differ by 1x or 2x and they're not resizable, short circuit
    BOOL shortCircuit = (variants.count == 1);
    if (variants.count == 2) {
        if (!variants[0][@"resizing"] && !variants[1][@"resizing"]) {
            NSString *filename1 = [variants[0][@"filename"] stringByReplacingOccurrencesOfString:@"@2x" withString:@""];
            NSString *filename2 = [variants[1][@"filename"] stringByReplacingOccurrencesOfString:@"@2x" withString:@""];
            shortCircuit = [filename1 isEqualToString:filename2];
        }
    }
    if (shortCircuit) {
        [implementation appendFormat:@"    return [UIImage imageNamed:@\"%@\"];\n", [variants lastObject][@"filename"]];
        [implementation appendString:@"}\n"];

    } else {
        [implementation appendString:@"    UIImage *image = nil;\n\n"];
        
        for (NSDictionary *variant in variants) {
            if (!variant[@"filename"]) {
                continue;
            }
            BOOL isUniversal = [variant[@"idiom"] isEqualToString:@"universal"];
            NSString *indentation = @"";
            if (!isUniversal) {
                NSString *idiom = [variant[@"idiom"] isEqualToString:@"iphone"] ? @"UIUserInterfaceIdiomPhone" : @"UIUserInterfaceIdiomPad";
                [implementation appendFormat:@"    if (UI_USER_INTERFACE_IDIOM() == %@) {\n", idiom];
                indentation = @"    ";
            }
            
            CGFloat scale = [variant[@"scale"] floatValue];
            NSString *filename = [variant[@"filename"] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"@%@", variant[@"scale"]] withString:@""];
            NSString *scaleIndentation = [indentation stringByAppendingString:@"    "];
            [implementation appendFormat:@"%@if ([UIScreen mainScreen].scale == %.1ff) {\n", scaleIndentation, scale];
            [implementation appendFormat:@"%@    image = [UIImage imageNamed:@\"%@\"];\n", scaleIndentation, filename];
            
            NSDictionary *resizing = variant[@"resizing"];
            if (resizing) {
                CGFloat top = [resizing[@"capInsets"][@"top"] floatValue] / scale;
                CGFloat left = [resizing[@"capInsets"][@"left"] floatValue] / scale;
                CGFloat bottom = [resizing[@"capInsets"][@"bottom"] floatValue] / scale;
                CGFloat right = [resizing[@"capInsets"][@"right"] floatValue] / scale;
                NSString *mode = [resizing[@"center"][@"mode"] isEqualToString:@"stretch"] ? @"UIImageResizingModeStretch" : @"UIImageResizingModeTile";
                
                [implementation appendFormat:@"%@    image = [image resizableImageWithCapInsets:UIEdgeInsetsMake(%.1ff, %.1ff, %.1ff, %.1ff) resizingMode:%@];\n", scaleIndentation, top, left, bottom, right, mode];
            }
            
            [implementation appendFormat:@"%@}\n", scaleIndentation];
            
            if (!isUniversal) {
                [implementation appendFormat:@"%@}\n", indentation];
            }
            
            [implementation appendString:@"\n"];
        }
        
        [implementation appendString:@"    return image;\n"];
        [implementation appendString:@"}\n"];
    }
    
    @synchronized(self.implementationContents) {
        [self.implementationContents addObject:implementation];
    }
}

@end
