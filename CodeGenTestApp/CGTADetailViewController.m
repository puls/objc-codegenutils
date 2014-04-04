//
//  CGTADetailViewController.m
//  CodeGenTestApp
//
//  Created by Jim Puls on 2/3/14.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "CGTADetailViewController.h"
#import "CGTATestAppColorList.h"
#import "CGTAMainStoryboardIdentifiers.h"


@interface CGTADetailViewController ()

@property (nonatomic, strong) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *tapLabel;
@property (weak, nonatomic) IBOutlet UILabel *countryNameLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *countryNameTopConstraint;

@end


@implementation CGTADetailViewController

- (void)setImage:(UIImage *)image;
{
    _image = image;
    [self updateView];
}

- (void)setCountryName:(NSString *)countryName;
{
    _countryName = countryName;
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
    
    // hide the label at first
    self.countryNameTopConstraint.constant = 0;
}

- (void)updateView;
{
    self.imageView.image = self.image;
    self.countryNameLabel.text = self.countryName;
}

- (IBAction)imageTapped:(UITapGestureRecognizer *)sender;
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        // the label was positioned perfectly via the storyboard, so now we can restore
        // the perfect positioning easily, by refering to the constant that was generated for us!
        self.countryNameTopConstraint.constant = self.countryNameTopConstraint.constant == 0 ? [self countryNameTopConstraintOriginalConstant] : 0;
        [UIView animateWithDuration:0.2
                         animations:^{
                             self.tapLabel.alpha = self.countryNameTopConstraint.constant == 0 ? 1 : 0;
                             [self.view layoutIfNeeded];
                         }];
    }
}

@end
