//
//  CDColorListDumper.m
//  codegenutils
//
//  Created by Jim Puls on 9/6/13.
//  Copyright (c) 2013 Square, Inc. All rights reserved.
//

#import "CDColorListDumper.h"
#import <Cocoa/Cocoa.h>


@implementation CDColorListDumper

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;
{
    NSString *colorListName = [[self.inputURL lastPathComponent] stringByDeletingPathExtension];

    self.className = [NSString stringWithFormat:@"%@%@ColorList", self.classPrefix, colorListName];

    NSColorList *colorList = [[NSColorList alloc] initWithName:colorListName fromFile:self.inputURL.path];
    
    // Install this color list
    [colorList writeToFile:nil];
    
    self.interfaceContents = [NSMutableArray array];
    self.implementationContents = [NSMutableArray array];
    
    for (NSString *key in colorList.allKeys) {
        NSColor *color = [colorList colorWithKey:key];
        if (![color.colorSpaceName isEqualToString:NSDeviceRGBColorSpace]) {
            printf("Color %s isn't device RGB. Skipping.", [key UTF8String]);
        }
        
        CGFloat r, g, b, a;
        [color getRed:&r green:&g blue:&b alpha:&a];
        
        NSString *declaration = [NSString stringWithFormat:@"+ (UIColor *)%@Color;\n", [self methodNameForKey:key]];
        [self.interfaceContents addObject:declaration];
        
        NSMutableString *method = [declaration mutableCopy];
        [method appendFormat:@"{\n    return [UIColor colorWithRed:%.3ff green:%.3ff blue:%.3ff alpha:%.3ff];\n}\n", r, g, b, a];
        [self.implementationContents addObject:method];
    }
    
    [self writeOutputFiles];
    completionBlock();
}

@end
