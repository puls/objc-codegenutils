//
//  AGCatalogParser.h
//  assetgen
//
//  Created by Jim Puls on 8/29/13.
//  Copyright (c) 2013 Square, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AGCatalogParser : NSObject

+ (instancetype)assetCatalogAtURL:(NSURL *)url;

@property (copy) NSString *classPrefix;

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;

@end
