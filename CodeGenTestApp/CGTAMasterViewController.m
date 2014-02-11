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


@interface CGTAFlagCollectionViewCell : UICollectionViewCell

@property (nonatomic, weak) IBOutlet UIImageView *imageView;

@end


@interface CGTAMasterViewController ()

@property (nonatomic, weak) IBOutlet UISlider *cellSizeSlider;
@property (nonatomic, strong) NSArray *flagImages;

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
    if ([segue.identifier isEqualToString:CGTAMainStoryboardTapOnFlagIdentifier]) {
        CGTADetailViewController *detailViewController = segue.destinationViewController;
        detailViewController.image = ((CGTAFlagCollectionViewCell *)sender).imageView.image;
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
    NSArray *allFlagImages = nil;

    // Initial version: full of strings that you have to type correctly!
    // Misspell any of these and your app will crash on trying to add `nil` to an array.
    allFlagImages = @[[UIImage imageNamed:@"USA"], [UIImage imageNamed:@"Canada"], [UIImage imageNamed:@"UK"], [UIImage imageNamed:@"Australia"]];

    // New version: get the properly compiler-checked spelling from the image catalog.
    allFlagImages = @[[CGTAImagesCatalog usaImage], [CGTAImagesCatalog canadaImage], [CGTAImagesCatalog ukImage], [CGTAImagesCatalog australiaImage]];

    // But really, why not use a little runtime hackery because we can?
    return [CGTAImagesCatalog allImages];
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
    CGTAFlagCollectionViewCell *cell = (CGTAFlagCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:CGTAMainStoryboardImageCellIdentifier forIndexPath:indexPath];
    cell.imageView.image = self.flagImages[indexPath.item];
    return cell;
}

@end


@implementation CGTAFlagCollectionViewCell
@end
