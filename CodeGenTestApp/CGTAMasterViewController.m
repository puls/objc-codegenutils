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
    // New version: get the properly compiler-checked spelling from the storyboard.
    // ... here we are guaranteed that tapOnFlag is one of our own view controller's segue and not some random one in the storyboard
    if ([segue.identifier isEqualToString:[self tapOnFlagSegueIdentifier]]) {
        CGTADetailViewController *detailViewController = segue.destinationViewController;
        detailViewController.image = ((CGTAFlagCollectionViewCell *)sender).imageView.image ?: [CGTAImagesCatalog usaImage];
    }
}

- (IBAction)pushTapped:(id)sender
{
    CGTADetailViewController *detailViewController = nil;
    
    // Initial version: full of strings that you have to type correctly!
    // Misspell any of these and your app will not work as expected.
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    detailViewController = [storyboard instantiateViewControllerWithIdentifier:@"Detail View Controller"];
    
    // New version: the two lines are combined into one ensuring that "Detail View Controller" does indeed belong to the "Main" storyboard
    detailViewController = [CGTAMainStoryboard instantiateDetailViewController];
    
    // ... also notice how this returns a CGTADetailViewController, rather than an id, so we can be assured that .image is a valid property!
    detailViewController.image = [CGTAImagesCatalog usaImage];
    [self.navigationController pushViewController:detailViewController animated:YES];
}

- (IBAction)performTapped:(id)sender
{
    // Initial version: uses a string that you have to type correctly!
    // Misspell this and your app will not work as expected.
#if 0
    [self performSegueWithIdentifier:@"Tap on Flag" sender:nil];
#endif

    // New version: get the properly compiler-checked spelling from the storyboard.
    [self performTapOnFlagSegue];
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
    CGTAFlagCollectionViewCell *cell = nil;

    // Initial version: we must type in the identifier, and have no guarantees as to which class it returns
    cell = (CGTAFlagCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"Image Cell" forIndexPath:indexPath];

    // New version: class extension which returns the exact type we are expecting
    cell = [self dequeueImageCellForIndexPath:indexPath ofCollectionView:collectionView];
    
    cell.imageView.image = self.flagImages[indexPath.item];
    return cell;
}

@end


@implementation CGTAFlagCollectionViewCell
@end
