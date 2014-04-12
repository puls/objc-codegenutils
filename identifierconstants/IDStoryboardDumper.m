//
//  IDStoryboardDumper.m
//  codegenutils
//
//  Created by Jim Puls on 2/3/14.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "IDStoryboardDumper.h"

@interface IDStoryboardDumper ()
/// Keys: NSString of class name; Values: @(BOOL) stating if it was successfully imported or not
@property (strong) NSMutableDictionary *classesImported;
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

- (NSString *)IDS_camelcaseString;
{
    NSString *output = [self IDS_titlecaseString];
    output = [NSString stringWithFormat:@"%@%@", [[output substringToIndex:1] lowercaseString], [output substringFromIndex:1]];
    return output;
}

- (NSString *)IDS_stringWithSuffix:(NSString *)suffix;
{
    if (![self hasSuffix:suffix]) {
        return [self stringByAppendingString:suffix];
    }
    return self;
}

- (NSString *)IDS_asPrefixOf:(NSString *)suffix;
{
    if (![suffix hasPrefix:self]) {
        return [self stringByAppendingString:suffix];
    }
    return self;
}

@end


@implementation IDStoryboardDumper

+ (NSString *)inputFileExtension;
{
    return @"storyboard";
}

/// element is any that have a customClass attribute and contain the valid default class name as their name (e.g. viewController, or tableViewCell)
- (NSString *)classTypeForElement:(NSXMLElement *)element importedCustomClass:(out BOOL *)importedCustomClass;
{
    if (importedCustomClass) {
        *importedCustomClass = NO;
    }
    
    NSString *customClass = [[element attributeForName:@"customClass"] stringValue];
    if (customClass && [self importClass:customClass]) {
        // we can use the custom class
        if (importedCustomClass) {
            *importedCustomClass = YES;
        }
        return customClass;
    } else {
        // element.name is the view controller type (e.g. tableViewController, navigationController, etc.)
        NSString *defaultClass = [@"UI" stringByAppendingString:[element.name IDS_titlecaseString]];
        return defaultClass;
    }
}

/// You may call this method multiple times with the same className without it having to search the search path each time. It will only search once and cache the result.
- (BOOL)importClass:(NSString *)className;
{
    if (!self.classesImported) {
        self.classesImported = [NSMutableDictionary dictionary];
    }
    
    if (self.classesImported[className]) {
        // if we have arleady tried searching for this class, there is no need to search for it again
        return [self.classesImported[className] boolValue];
    }
    
    BOOL successfullyImported = NO;
    if ([self.headerFilesFound containsObject:className]) {
        [self.interfaceImports addObject:[NSString stringWithFormat:@"\"%@.h\"", className]];
        successfullyImported = YES;
    }
    
    if (!successfullyImported) {
        NSLog(@"Unable to find class interface for '%@'. Reverting to global string constant behavior.", className);
    }
    self.classesImported[className] = @(successfullyImported);
    return successfullyImported;
}

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;
{
    self.skipClassDeclaration = YES;
    NSString *storyboardFilename = [[self.inputURL lastPathComponent] stringByDeletingPathExtension];
    NSString *storyboardName = [storyboardFilename stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    self.className = [NSString stringWithFormat:@"%@%@StoryboardIdentifiers", self.classPrefix, storyboardName];
    NSError *error = nil;
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithContentsOfURL:self.inputURL options:0 error:&error];

    NSArray *storyboardIdentifiers = [[document nodesForXPath:@"//@storyboardIdentifier" error:&error] valueForKey:NSStringFromSelector(@selector(stringValue))];
    NSArray *reuseIdentifiers = [[document nodesForXPath:@"//@reuseIdentifier" error:&error] valueForKey:NSStringFromSelector(@selector(stringValue))];
    NSArray *segueIdentifiers = [[document nodesForXPath:@"//segue/@identifier" error:&error] valueForKey:NSStringFromSelector(@selector(stringValue))];
    
    NSMutableArray *identifiers = [NSMutableArray arrayWithArray:storyboardIdentifiers];
    [identifiers addObjectsFromArray:reuseIdentifiers];
    [identifiers addObjectsFromArray:segueIdentifiers];
    
    self.interfaceImports = [NSMutableSet set];
    self.classes = [NSMutableDictionary dictionary];
    self.interfaceContents = [NSMutableArray array];
    self.implementationContents = [NSMutableArray array];
    
    
    NSMutableArray *viewControllers = [NSMutableArray array];;
    [viewControllers addObjectsFromArray:[document nodesForXPath:@"//viewController" error:&error]];
    [viewControllers addObjectsFromArray:[document nodesForXPath:@"//tableViewController" error:&error]];
    [viewControllers addObjectsFromArray:[document nodesForXPath:@"//collectionViewController" error:&error]];
    [viewControllers addObjectsFromArray:[document nodesForXPath:@"//pageViewController" error:&error]];
    [viewControllers addObjectsFromArray:[document nodesForXPath:@"//navigationController" error:&error]];
    [viewControllers addObjectsFromArray:[document nodesForXPath:@"//tabBarController" error:&error]];
    // TODO: add support for GLKViewControllers
    
    [viewControllers sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSString *storyboardIdentifier1 = [[[obj1 attributeForName:@"storyboardIdentifier"] stringValue] IDS_titlecaseString];
        NSString *storyboardIdentifier2 = [[[obj2 attributeForName:@"storyboardIdentifier"] stringValue] IDS_titlecaseString];
        return [storyboardIdentifier1 caseInsensitiveCompare:storyboardIdentifier2];
    }];
    
    CGUClass *storyboardClass = [CGUClass new];
    storyboardClass.name = [self.classPrefix IDS_asPrefixOf:[NSString stringWithFormat:@"%@Storyboard", storyboardName]];
    storyboardClass.superClassName = @"NSObject";
    self.classes[storyboardClass.name] = storyboardClass;
    
    // output + [MYMainStoryboard storyboard]
    CGUMethod *storyboardMethod = [CGUMethod new];
    storyboardMethod.classMethod = YES;
    storyboardMethod.returnType = @"UIStoryboard *";
    storyboardMethod.nameAndArguments = @"storyboard";
    storyboardMethod.body = [NSString stringWithFormat:@"    return [UIStoryboard storyboardWithName:@\"%@\" bundle:nil];", storyboardName];
    [storyboardClass.methods addObject:storyboardMethod];
    
    NSString *initialViewControllerID = [[[document rootElement] attributeForName:@"initialViewController"] stringValue];
    if (initialViewControllerID) {
        NSString *initialViewControllerClass = nil;
        for (NSXMLElement *viewControllerElement in viewControllers) {
            if ([[[viewControllerElement attributeForName:@"id"] stringValue] isEqualToString:initialViewControllerID]) {
                // found initial view controller
                initialViewControllerClass = [self classTypeForElement:viewControllerElement importedCustomClass:NULL];
                break;
            }
        }
        
        if (initialViewControllerClass) {
            // output + [MYMainStoryboard instantiateInitialViewController]
            CGUMethod *instantiateInitialViewControllerMethod = [CGUMethod new];
            instantiateInitialViewControllerMethod.classMethod = YES;
            instantiateInitialViewControllerMethod.returnType = [NSString stringWithFormat:@"%@ *", initialViewControllerClass];
            instantiateInitialViewControllerMethod.nameAndArguments = @"instantiateInitialViewController";
            instantiateInitialViewControllerMethod.body = @"    return [[self storyboard] instantiateInitialViewController];";
            [storyboardClass.methods addObject:instantiateInitialViewControllerMethod];
        } else {
            NSLog(@"Warning: Initial view controller exists, but wasn't found in the storyboard: %@", initialViewControllerID);
        }
    }
    
    for (NSXMLElement *viewControllerElement in viewControllers) {
        NSString *storyboardIdentifier = [[viewControllerElement attributeForName:@"storyboardIdentifier"] stringValue];
        BOOL importedCustomClass = NO;
        NSString *className = [self classTypeForElement:viewControllerElement importedCustomClass:&importedCustomClass];
        if (storyboardIdentifier) {
            [identifiers removeObject:storyboardIdentifier]; // prevent user from using the old string, they can now access it via [MYMainStoryboard instantiate...]

            // output + [MYMainStoryboard instantiateMyCustomViewController]
            CGUMethod *instantiateCustomViewControllerMethod = [CGUMethod new];
            instantiateCustomViewControllerMethod.classMethod = YES;
            instantiateCustomViewControllerMethod.returnType = [NSString stringWithFormat:@"%@ *", className];
            instantiateCustomViewControllerMethod.nameAndArguments = [@"instantiate" stringByAppendingString:[[storyboardIdentifier IDS_titlecaseString] IDS_stringWithSuffix:@"Controller"]];
            instantiateCustomViewControllerMethod.body = [NSString stringWithFormat:@"    return [[self storyboard] instantiateViewControllerWithIdentifier:@\"%@\"];", storyboardIdentifier];
            [storyboardClass.methods addObject:instantiateCustomViewControllerMethod];
        }
        
        if (importedCustomClass) {
            CGUClass *viewControllerClassCategory = self.classes[className]; // we may see the same class twice, so it is storyed in a dictionary
            if (viewControllerClassCategory == nil) {
                viewControllerClassCategory = [CGUClass new];
                viewControllerClassCategory.name = className;
                viewControllerClassCategory.categoryName = [NSString stringWithFormat:@"ObjcCodeGenUtils_%@", storyboardName];
                self.classes[className] = viewControllerClassCategory;
            }
            
            NSArray *segueIdentifiers = [[viewControllerElement nodesForXPath:@".//segue/@identifier" error:&error] valueForKey:NSStringFromSelector(@selector(stringValue))];
            for (NSString *segueIdentifier in segueIdentifiers) {
                [identifiers removeObject:segueIdentifier]; // we don't want the user accessing this segue via the old method
                
                // output - [(MYCustomViewController *) myCustomSegueIdentifier]
                CGUMethod *segueIdentifierMethod = [CGUMethod new];
                segueIdentifierMethod.returnType = @"NSString *";
                segueIdentifierMethod.nameAndArguments = [[[segueIdentifier IDS_camelcaseString] IDS_stringWithSuffix:@"Segue"] stringByAppendingString:@"Identifier"];
                segueIdentifierMethod.body = [NSString stringWithFormat:@"    return @\"%@\";", segueIdentifier];
                [viewControllerClassCategory.methods addObject:segueIdentifierMethod];
                
                // output - [(MYCustomViewController *) performMyCustomSegue]
                CGUMethod *performSegueMethod = [CGUMethod new];
                performSegueMethod.nameAndArguments = [@"perform" stringByAppendingString:[[segueIdentifier IDS_titlecaseString] IDS_stringWithSuffix:@"Segue"]];
                performSegueMethod.body = [NSString stringWithFormat:@"    [self performSegueWithIdentifier:[self %@] sender:nil];", segueIdentifierMethod.nameAndArguments];
                [viewControllerClassCategory.methods addObject:performSegueMethod];
            }
            
            NSArray *reuseIdentifiers = [viewControllerElement nodesForXPath:@".//*[@reuseIdentifier]" error:&error];
            for (NSXMLElement *reuseIdentifierElement in reuseIdentifiers) {
                NSString *reuseIdentifier = [[reuseIdentifierElement attributeForName:@"reuseIdentifier"] stringValue];
                [identifiers removeObject:reuseIdentifier];
                
                // output - (NSString *)[(MYCustomViewController *) myCustomCellIdentifier];
                CGUMethod *reuseIdentifierMethod = [CGUMethod new];
                reuseIdentifierMethod.returnType = @"NSString *";
                reuseIdentifierMethod.nameAndArguments = [[reuseIdentifier IDS_camelcaseString] IDS_stringWithSuffix:@"Identifier"];
                reuseIdentifierMethod.body = [NSString stringWithFormat:@"    return @\"%@\";", reuseIdentifier];
                [viewControllerClassCategory.methods addObject:reuseIdentifierMethod];

                NSString *elementName = reuseIdentifierElement.name; // E.g. collectionViewCell, tableViewCell, etc.
                NSString *methodNameSecondArgument = nil;
                NSString *code = nil;
                if ([elementName isEqualToString:@"tableViewCell"]) {
                    methodNameSecondArgument = @"ofTableView:(UITableView *)tableView";
                    code = [NSString stringWithFormat:@"[tableView dequeueReusableCellWithIdentifier:@\"%@\" forIndexPath:indexPath]", reuseIdentifier];
                } else if ([elementName isEqualToString:@"collectionViewCell"] || [elementName isEqualToString:@"collectionReusableView"]) {
                    methodNameSecondArgument = @"ofCollectionView:(UICollectionView *)collectionView";
                    code = [NSString stringWithFormat:@"[collectionView dequeueReusableCellWithReuseIdentifier:@\"%@\" forIndexPath:indexPath]", reuseIdentifier];
                } else {
                    NSLog(@"Warning: Unknown reuse identifier %@.", elementName);
                    continue;
                }

                NSString *reuseIdentifierClassName = [self classTypeForElement:reuseIdentifierElement importedCustomClass:NULL];

                // output - (MYCustomCell *)[(MYCustomViewController *) dequeueMyCustomCellForIndexPath:ofTableView:]
                CGUMethod *dequeueMethod = [CGUMethod new];
                dequeueMethod.returnType = [NSString stringWithFormat:@"%@ *", reuseIdentifierClassName];
                dequeueMethod.nameAndArguments = [NSString stringWithFormat:@"dequeue%@ForIndexPath:(NSIndexPath *)indexPath %@", [[reuseIdentifier IDS_titlecaseString] IDS_stringWithSuffix:@"Cell"], methodNameSecondArgument];
                dequeueMethod.body = [NSString stringWithFormat:@"    return %@;", code];
                [viewControllerClassCategory.methods addObject:dequeueMethod];
                
                // TODO: add support for [collectionView dequeueReusableSupplementaryViewOfKind:(NSString *) withReuseIdentifier:(NSString *) forIndexPath:(NSIndexPath *)]
            }
            
            // Ex: <constraint firstItem="lYE-JU-xj6" firstAttribute="top" secondItem="cR7-VS-ItW" secondAttribute="bottom" constant="97" id="fV7-6P-89B"/>
            NSArray *constraints = [viewControllerElement nodesForXPath:@".//constraint[@constant]" error:NULL];
            for (NSXMLElement *constraint in constraints) {
                NSString *constraintId = [[constraint attributeForName:@"id"] stringValue];
                NSXMLElement *node = [[viewControllerElement nodesForXPath:[NSString stringWithFormat:@"./connections/outlet[@destination='%@']", constraintId] error:NULL] firstObject];
                if (node) {
                    // Ex: <outlet property="buttonTopConstraint" destination="fV7-6P-89B" id="nRh-hX-uwu"/>
                    NSString *propertyName = [[node attributeForName:@"property"] stringValue];
                    CGFloat constant = [[[constraint attributeForName:@"constant"] stringValue] floatValue];
                    
                    // ouptut - (CGFloat)[(MYCustomViewController *) myCustomConstraintOriginalConstant]
                    CGUMethod *constraintMethod = [CGUMethod new];
                    constraintMethod.returnType = @"CGFloat";
                    constraintMethod.nameAndArguments = [NSString stringWithFormat:@"%@OriginalConstant", [[propertyName IDS_camelcaseString] IDS_stringWithSuffix:@"Constraint"]];
                    constraintMethod.body = [NSString stringWithFormat:@"    return %f;", constant];
                    [viewControllerClassCategory.methods addObject:constraintMethod];
                }
            }
        }
    }
    
    NSMutableDictionary *uniqueKeys = [NSMutableDictionary dictionary];
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
