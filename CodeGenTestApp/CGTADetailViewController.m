//
//  CGTADetailViewController.m
//  CodeGenTestApp
//
//  Created by Jim Puls on 2/3/14.
//  Copyright (c) 2014 Square, Inc. All rights reserved.
//

#import "CGTADetailViewController.h"
#import "CGTATestAppColorList.h"


@interface CGTADetailViewController ()

@property (nonatomic, strong) IBOutlet UIImageView *imageView;

@end


@implementation CGTADetailViewController

- (void)setImage:(UIImage *)image;
{
    _image = image;
    [self updateView];
}

- (void)viewDidLoad;
{
    [self updateView];
    
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.startPoint = CGPointMake(0.5, 0.5);
    layer.endPoint = CGPointMake(0.5, 1.0);
    
    layer.colors = @[(id)[UIColor whiteColor].CGColor, (id)[CGTATestAppColorList tealColor].CGColor];
    layer.frame = self.view.layer.bounds;
    [self.view.layer insertSublayer:layer atIndex:0];
}

- (void)updateView;
{
    self.imageView.image = self.image;
}

@end
