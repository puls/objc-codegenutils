//
//  CDColorListDumper.m
//  codegenutils
//
//  Created by Jim Puls on 9/6/13.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "CDColorListDumper.h"


@implementation CDColorListDumper

+ (NSString *)inputFileExtension;
{
    return @"clr";
}

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;
{
    NSString *colorListName = [[self.inputURL lastPathComponent] stringByDeletingPathExtension];

    self.className = [[NSString stringWithFormat:@"%@%@ColorList", self.classPrefix, colorListName]stringByReplacingOccurrencesOfString:@" " withString:@""];

    NSColorList *colorList = [[NSColorList alloc] initWithName:colorListName fromFile:self.inputURL.path];
    
    // Install this color list
    [colorList writeToFile:nil];
    
    self.interfaceContents = [NSMutableArray array];
    self.implementationContents = [NSMutableArray array];
    
    for (NSString *key in colorList.allKeys) {
        NSColor *color = [colorList colorWithKey:key];
		
		if([color.colorSpaceName isEqualToString:NSCalibratedRGBColorSpace])
		{
			color = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
		}
		else if([color.colorSpaceName isEqualToString:NSCalibratedWhiteColorSpace])
		{
			color = [color colorUsingColorSpaceName:NSDeviceWhiteColorSpace];
		}
		
        if ([color.colorSpaceName isEqualToString:NSDeviceRGBColorSpace])
		{
			CGFloat r, g, b, a;
			[color getRed:&r green:&g blue:&b alpha:&a];
			
			NSString *declaration = [NSString stringWithFormat:@"+ (UIColor *)%@Color;\n", [self methodNameForKey:key]];
			[self.interfaceContents addObject:declaration];
			
			NSMutableString *method = [declaration mutableCopy];
			[method appendFormat:@"{\n\treturn [UIColor colorWithRed:%.3ff green:%.3ff blue:%.3ff alpha:%.3ff];\n}\n", r, g, b, a];
			[self.implementationContents addObject:method];
		}
		else if([color.colorSpaceName isEqualToString:NSDeviceWhiteColorSpace])
		{
			CGFloat w, a;
			[color getWhite:&w alpha:&a];
			
			NSString *declaration = [NSString stringWithFormat:@"+ (UIColor *)%@Color;\n", [self methodNameForKey:key]];
			[self.interfaceContents addObject:declaration];
			
			NSMutableString *method = [declaration mutableCopy];
			[method appendFormat:@"{\n\treturn [UIColor colorWithWhite:%.3f alpha:%.3f];\n}\n", w, a];
			[self.implementationContents addObject:method];
		}
		else
		{
            printf("Color %s isn't supported. Skipping.\n", [key UTF8String]);
            continue;
        }
    }
    
    [self writeOutputFiles];
    completionBlock();
}

@end
