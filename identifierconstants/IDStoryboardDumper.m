//
//  IDStoryboardDumper.m
//  codegenutils
//
//  Created by Jim Puls on 2/3/14.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "IDStoryboardDumper.h"


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

- (NSString *)IDS_stringWithSuffix:(NSString *)suffix {
    if (![self hasSuffix:suffix]) {
        return [self stringByAppendingString:suffix];
    }
    return self;
}

- (NSString *)IDS_asPrefixOf:(NSString *)suffix {
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

- (NSString *)classTypeForViewControllerElement:(NSXMLElement *)viewControllerElement
{
    // element.name is the view controller type (e.g. tableViewController, navigationController, etc.)
    return [[viewControllerElement attributeForName:@"customClass"] stringValue] ?: [@"UI" stringByAppendingString:[viewControllerElement.name IDS_titlecaseString]];
}

- (void)importClass:(NSString *)className
{
    NSTask *findFiles = [NSTask new];
    [findFiles setLaunchPath:@"/usr/bin/grep"];
    [findFiles setCurrentDirectoryPath:self.searchPath];
    [findFiles setArguments:[[NSString stringWithFormat:@"-r -l -e @interface[[:space:]]\\{1,\\}%@[[:space:]]*:[[:space:]]*[[:alpha:]]\\{1,\\} .", className] componentsSeparatedByString:@" "]];
    
    NSPipe *pipe = [NSPipe pipe];
    [findFiles setStandardOutput:pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    
    [findFiles launch];
    [findFiles waitUntilExit];
    
    NSData *data = [file readDataToEndOfFile];
    
    NSString *string = [[NSString alloc] initWithData: data encoding:NSUTF8StringEncoding];
    NSArray *lines = [string componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSURL *path = [NSURL URLWithString:line];
        NSString *importFile = [path lastPathComponent];
        if ([importFile hasSuffix:@".h"]) {
            [self.interfaceImports addObject:[NSString stringWithFormat:@"\"%@\"", importFile]];
            break;
        }
    }
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
    
    self.interfaceContents = [NSMutableArray array];
    self.implementationContents = [NSMutableArray array];

    NSMutableDictionary *uniqueKeys = [NSMutableDictionary dictionary];
    uniqueKeys[[NSString stringWithFormat:@"%@%@StoryboardName", self.classPrefix, storyboardName]] = storyboardFilename;
    
    if (self.uberMode) {
        self.interfaceImports = [NSMutableArray array];
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
        
        NSString *nonUberStoryboardNameKey = [NSString stringWithFormat:@"%@%@StoryboardName", self.classPrefix, storyboardName];
        [uniqueKeys removeObjectForKey:nonUberStoryboardNameKey];
        NSString *storyboardClassName = [self.classPrefix IDS_asPrefixOf:[NSString stringWithFormat:@"%@Storyboard", storyboardName]];
        
        // output @interface MYMainStoryboard : NSObject
        [self.interfaceContents addObject:[NSString stringWithFormat:@"@interface %@ : NSObject\n", storyboardClassName]];
        [self.implementationContents addObject:[NSString stringWithFormat:@"@implementation %@\n", storyboardClassName]];
        
        // output + [MYMainStoryboard storyboard]
        [self.interfaceContents addObject:@"+ (UIStoryboard *)storyboard;\n"];
        [self.implementationContents addObject:@"+ (UIStoryboard *)storyboard {\n"];
        [self.implementationContents addObject:[NSString stringWithFormat:@"    return [UIStoryboard storyboardWithName:@\"%@\" bundle:nil];\n", storyboardName]];
        [self.implementationContents addObject:@"}\n"];
        
        // output + [MYMainStoryboard instantiateInitialViewController]
        NSString *initialViewControllerID = [[[document rootElement] attributeForName:@"initialViewController"] stringValue];
        if (initialViewControllerID) {
            for (NSXMLElement *viewControllerElement in viewControllers) {
                if (![[[viewControllerElement attributeForName:@"id"] stringValue] isEqualToString:initialViewControllerID])
                    continue;
                
                // found initial view controller
                NSString *customClass = [self classTypeForViewControllerElement:viewControllerElement];
                [self.interfaceContents addObject:[NSString stringWithFormat:@"+ (%@ *)instantiateInitialViewController;\n", customClass]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"+ (%@ *)instantiateInitialViewController {\n", customClass]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"    return [[self storyboard] instantiateInitialViewController];\n"]];
                [self.implementationContents addObject:@"}\n"];
                break;
            }
        }
        
        for (NSXMLElement *viewControllerElement in viewControllers) {
            NSString *storyboardIdentifier = [[viewControllerElement attributeForName:@"storyboardIdentifier"] stringValue];
            NSString *customClass = [[viewControllerElement attributeForName:@"customClass"] stringValue];
            if (customClass) {
                // output #import "MYCustomViewController.h"
                [self importClass:customClass];
            }
            
            if (!storyboardIdentifier) {
                continue;
            }
            
            [identifiers removeObject:storyboardIdentifier]; // prevent user from using the old strings
            NSString *className = [self classTypeForViewControllerElement:viewControllerElement];

            
            NSString *methodName = [@"instantiate" stringByAppendingString:[[storyboardIdentifier IDS_titlecaseString] IDS_stringWithSuffix:@"Controller"]];
            
            // output + [MYMainStoryboard instatiateMyCustomViewController]
            [self.interfaceContents addObject:[NSString stringWithFormat:@"+ (%@ *)%@;\n", className, methodName]];
            [self.implementationContents addObject:[NSString stringWithFormat:@"+ (%@ *)%@ {\n", className, methodName]];
            [self.implementationContents addObject:[NSString stringWithFormat:@"    return [[self storyboard] instantiateViewControllerWithIdentifier:@\"%@\"];\n", storyboardIdentifier]];
            [self.implementationContents addObject:[NSString stringWithFormat:@"}\n"]];
        }
        [self.interfaceContents addObject:@"@end\n\n"];
        [self.implementationContents addObject:@"@end\n\n"];
        
        NSInteger uniqueNumber = 0; // TODO: instead of using this hack, combine all the methods into a single category. Also deal with multiple storyboards that reference the same class.
        for (NSXMLElement *viewControllerElement in viewControllers) {
            NSString *customClass = [[viewControllerElement attributeForName:@"customClass"] stringValue];
            if (!customClass) {
                continue;
            }
            
            NSArray *segueIdentifiers = [[viewControllerElement nodesForXPath:@".//segue/@identifier" error:&error] valueForKey:NSStringFromSelector(@selector(stringValue))];
            NSArray *reuseIdentifiers = [viewControllerElement nodesForXPath:@".//*[@reuseIdentifier]" error:&error];
            if (segueIdentifiers.count == 0 && reuseIdentifiers.count == 0) {
                // nothing to output
                continue;
            }
            
            // output @interface MYCustomViewController (ObjcCodeGenUtils)
            NSString *categoryName = [NSString stringWithFormat:@"ObjcCodeGenUtils_%@_%ld", storyboardName, (long)uniqueNumber++];
            [self.interfaceContents addObject:[NSString stringWithFormat:@"@interface %@ (%@)\n", customClass, categoryName]];
            [self.implementationContents addObject:[NSString stringWithFormat:@"@implementation %@ (%@)\n", customClass, categoryName]];
            
            for (NSString *segueIdentifier in segueIdentifiers) {
                [identifiers removeObject:segueIdentifier]; // we don't want the user accessing this segue via the old method
                
                // output + [(MYCustomViewController *) myCustomSegueIdentifier]
                NSString *segueIdentifierMethodName = [[[segueIdentifier IDS_camelcaseString] IDS_stringWithSuffix:@"Segue"] stringByAppendingString:@"Identifier"];
                [self.interfaceContents addObject:[NSString stringWithFormat:@"+ (NSString *)%@;\n", segueIdentifierMethodName]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"+ (NSString *)%@ {\n", segueIdentifierMethodName]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"    return @\"%@\";\n", segueIdentifier]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"}\n"]];
                
                // output - [(MYCustomViewController *) myCustomSegueIdentifier]
                [self.interfaceContents addObject:[NSString stringWithFormat:@"- (NSString *)%@;\n", segueIdentifierMethodName]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"- (NSString *)%@ {\n", segueIdentifierMethodName]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"    return @\"%@\";\n", segueIdentifier]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"}\n"]];
                
                // output - [(MYCustomViewController *) performMyCustomSegue]
                NSString *performSegueMethodName = [[segueIdentifier IDS_titlecaseString] IDS_stringWithSuffix:@"Segue"];
                [self.interfaceContents addObject:[NSString stringWithFormat:@"- (void)perform%@;\n", performSegueMethodName]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"- (void)perform%@ {\n", performSegueMethodName]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"    [self performSegueWithIdentifier:[self %@] sender:nil];\n", segueIdentifierMethodName]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"}\n"]];
            }
            
            for (NSXMLElement *reuseIdentifierElement in reuseIdentifiers) {
                NSString *customClass = [[reuseIdentifierElement attributeForName:@"customClass"] stringValue];
                if (customClass) {
                    [self importClass:customClass];
                }
                NSString *elementName = reuseIdentifierElement.name; // E.g. collectionViewCell, tableViewCell, etc.
                NSString *className = customClass ?: [@"UI" stringByAppendingString:[reuseIdentifierElement.name IDS_titlecaseString]];
                NSString *reuseIdentifier = [[reuseIdentifierElement attributeForName:@"reuseIdentifier"] stringValue];
                [identifiers removeObject:reuseIdentifier];
                
                NSString *methodNameSecondArgument = nil;
                NSString *code = nil;
                
                if ([elementName isEqualToString:@"tableViewCell"]) {
                    methodNameSecondArgument = @"ofTableView:(UITableView *)tableView";
                    code = [NSString stringWithFormat:@"[tableView dequeueReusableCellWithIdentifier:@\"%@\" forIndexPath:indexPath]", reuseIdentifier];
                } else if ([elementName isEqualToString:@"collectionViewCell"] || [elementName isEqualToString:@"collectionReusableView"]) {
                    methodNameSecondArgument = @"ofCollectionView:(UICollectionView *)collectionView";
                    code = [NSString stringWithFormat:@"[collectionView dequeueReusableCellWithReuseIdentifier:@\"%@\" forIndexPath:indexPath]", reuseIdentifier];
                }
                // TODO: add support for     [collectionView dequeueReusableSupplementaryViewOfKind:(NSString *) withReuseIdentifier:(NSString *) forIndexPath:(NSIndexPath *)]
                
                // output - (NSString *)[(MYCustomViewController *) myCustomCellIdentifier];
                NSString *reuseIdentifierMethodName = [[reuseIdentifier IDS_camelcaseString] IDS_stringWithSuffix:@"Identifier"];
                [self.interfaceContents addObject:[NSString stringWithFormat:@"- (NSString *)%@;\n", reuseIdentifierMethodName]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"- (NSString *)%@ {\n", reuseIdentifierMethodName]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"    return @\"%@\";\n", reuseIdentifier]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"}\n"]];
                
                
                // output - (MYCustomCell *)[(MYCustomViewController *) dequeueMyCustomCellForIndexPath:ofTableView:]
                NSString *methodName = [NSString stringWithFormat:@"dequeue%@ForIndexPath:(NSIndexPath *)indexPath %@", [[reuseIdentifier IDS_titlecaseString] IDS_stringWithSuffix:@"Cell"], methodNameSecondArgument];
                [self.interfaceContents addObject:[NSString stringWithFormat:@"- (%@ *)%@;\n", className, methodName]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"- (%@ *)%@ {\n", className, methodName]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"    return %@;\n", code]];
                [self.implementationContents addObject:[NSString stringWithFormat:@"}\n"]];
            }
            
            
            [self.interfaceContents addObject:@"@end\n\n"];
            [self.implementationContents addObject:@"@end\n\n"];
        }
    }
    
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
