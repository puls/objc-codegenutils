//
//  CGUCodeGenTool.h
//  codegenutils
//
//  Created by Jim Puls on 9/6/13.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, CGUClassType) {
    CGUClassType_Definition,
    CGUClassType_Extension,
    CGUClassType_Category
};

@interface CGUCodeGenTool : NSObject

+ (int)startWithArgc:(int)argc argv:(const char **)argv;

+ (NSString *)inputFileExtension;

@property (copy) NSURL *inputURL;
@property (copy) NSString *classPrefix;
@property (copy) NSString *searchPath;
@property BOOL targetiOS6;
@property BOOL skipClassDeclaration;

@property (copy) NSString *className;
/// An array of strings such as "<Foundation/Foundation.h>" which will be imported at the top of the .h file.
@property (strong) NSMutableArray *interfaceImports;
/// A dictionary of class names as keys (NSString *), and CGUClass instances as values.
@property (strong) NSMutableDictionary *classes;
@property (strong) NSMutableArray *interfaceContents;
@property (strong) NSMutableArray *implementationContents;

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;

- (void)writeOutputFiles;

- (NSString *)methodNameForKey:(NSString *)key;

@end



@interface CGUClass : NSObject

/// The class type is determined by the following:
/// - If there is a superClassName, this is a class definition
/// - If there is a clategoryName, this is a category
/// - Otherwise, this is a class extension
@property (readonly) CGUClassType classType;
@property (copy) NSString *categoryName;
/// An array of CGUMethods
@property (strong) NSMutableArray *methods;
@property (copy) NSString *name;
@property (copy) NSString *superClassName;

- (NSString *)interfaceCode;
- (NSString *)implementationCode;

@end



@interface CGUMethod : NSObject

/// Specifies if this is an class method rather than an instance method.
@property BOOL classMethod;

/// E.g. "NSString *"
/// If this is nil, it will be replaced with void.
@property NSString *returnType;

/// E.g. "doSomethingWithString:(NSString *)myString andNumber:(NSInteger)number"
@property (copy) NSString *nameAndArguments;
@property (copy) NSString *body;

- (NSString *)interfaceCode;
- (NSString *)implementationCode;

@end
