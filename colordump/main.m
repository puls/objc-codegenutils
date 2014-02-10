//
//  main.m
//  colordump
//
//  Created by Jim Puls on 9/6/13.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "CDColorListDumper.h"


int main(int argc, const char * argv[])
{
    @autoreleasepool {
        return [CDColorListDumper startWithArgc:argc argv:argv];
    }
}
