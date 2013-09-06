//
//  CGCodeGenTool.h
//  codegenutils
//
//  Created by Jim Puls on 9/6/13.
//  Copyright (c) 2013 Square, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface CGUCodeGenTool : NSObject

+ (int)startWithArgc:(int)argc argv:(const char **)argv;

+ (NSString *)inputFileExtension;

@property (copy) NSURL *inputURL;
@property (copy) NSString *classPrefix;

@property (copy) NSString *className;
@property (strong) NSMutableArray *interfaceContents;
@property (strong) NSMutableArray *implementationContents;

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;

- (void)writeOutputFiles;

- (NSString *)methodNameForKey:(NSString *)key;

@end
