//
//  CGTAMasterViewController.m
//  CodeGenTestApp
//
//  Created by Jim Puls on 2/3/14.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "CGTAMasterViewController.h"
#import "CGTADetailViewController.h"
#import "CGTAImagesCatalog+RuntimeHackery.h"
#import "CGTAMainStoryboardIdentifiers.h"
#import "CGTAFlagCollectionViewCell.h"

@interface CGTAMasterViewController ()

@property (nonatomic, weak) IBOutlet UISlider *cellSizeSlider;
@property (nonatomic, strong) NSArray *flagImages;
@property (nonatomic, strong) NSArray *flagImageNames;

@end


@implementation CGTAMasterViewController

#pragma mark - NSObject

- (void)awakeFromNib;
{
    [self sliderValueChanged:self.cellSizeSlider];
}

#pragma mark - UIViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender;
{
    if ([segue.identifier isEqualToString:[self tapOnFlagSegueIdentifier]]) {
        CGTADetailViewController *detailViewController = segue.destinationViewController;
        CGTAFlagCollectionViewCell *cellSender = sender;
        detailViewController.image = cellSender.imageView.image;
        detailViewController.countryName = cellSender.countryName;
    }
}

#pragma mark - Private methods

- (IBAction)sliderValueChanged:(UISlider *)sender;
{
    float newValue = sender.value;
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    layout.itemSize = CGSizeMake(newValue, newValue);
}

- (NSArray *)flagImages;
{
    if (!_flagImages) {
        // What you might have done without this tool: full of strings that you have to type correctly!
        // Misspell any of these and your app will crash on trying to add `nil` to an array.
        _flagImages = @[[UIImage imageNamed:@"USA"], [UIImage imageNamed:@"Canada"], [UIImage imageNamed:@"UK"], [UIImage imageNamed:@"Australia"]];
        
        // New version: get the properly compiler-checked spelling from the image catalog.
        _flagImages = @[[CGTAImagesCatalog usaImage], [CGTAImagesCatalog canadaImage], [CGTAImagesCatalog ukImage], [CGTAImagesCatalog australiaImage]];
        
        // But really, why not use a little runtime hackery because we can?
        _flagImages = [CGTAImagesCatalog allImages];
    }
    return _flagImages;
}

- (NSArray *)flagImageNames;
{
    if (!_flagImageNames) {
        _flagImageNames = [CGTAImagesCatalog allImageNames];
    }
    return _flagImageNames;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView;
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section;
{
    return self.flagImages.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;
{
    CGTAFlagCollectionViewCell *cell = nil;

    // What you might have done without this tool: we must type in the identifier, and have no guarantees as to which class it returns
    cell = (CGTAFlagCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"Image Cell" forIndexPath:indexPath];

    // New version: class extension which returns the exact type we are expecting
    cell = [self dequeueImageCellForIndexPath:indexPath ofCollectionView:collectionView];
    
    cell.imageView.image = self.flagImages[indexPath.item];
    cell.countryName = self.flagImageNames[indexPath.item];
    return cell;
}

@end
