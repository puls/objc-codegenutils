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

// To disable uber mode:
// 1. Comment out the "#define UBER_MODE" below
// 2. Go to the target's build phases settings, and remove the -u option from the objc-identifierconstants command
#define UBER_MODE


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
#ifndef UBER_MODE
    // New version: get the properly compiler-checked spelling from the storyboard.
    if ([segue.identifier isEqualToString:CGTAMainStoryboardTapOnFlagIdentifier]) {
        CGTADetailViewController *detailViewController = segue.destinationViewController;
        detailViewController.image = ((CGTAFlagCollectionViewCell *)sender).imageView.image ?: [CGTAImagesCatalog usaImage];
    }
#else
    // But really, why not use class methods?
    // ... here we are guaranteed that topOnFlag is our own view controller's segue and not some random one in the storyboard
    if ([segue.identifier isEqualToString:[self tapOnFlagSegueIdentifier]]) {
        CGTADetailViewController *detailViewController = segue.destinationViewController;
        detailViewController.image = ((CGTAFlagCollectionViewCell *)sender).imageView.image ?: [CGTAImagesCatalog usaImage];
    }
#endif
}

- (IBAction)pushTapped:(id)sender
{
    CGTADetailViewController *detailViewController = nil;
    
#ifndef UBER_MODE
    UIStoryboard *storyboard = nil;
    
    // Initial version: full of strings that you have to type correctly!
    // Misspell any of these and your app will not work as expected.
    storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    detailViewController = [storyboard instantiateViewControllerWithIdentifier:@"Detail View Controller"];
    
    // New version: get the properly compiler-checked spelling from the storyboard.
    storyboard = [UIStoryboard storyboardWithName:CGTAMainStoryboardName bundle:nil];
    // ... there is no guarantee that the storyboard actually has an identifier named CGTAMainStoryboardDetailViewControllerIdentifier. We are using two different constants that we must manually guarantee are in sync.
    detailViewController = [storyboard instantiateViewControllerWithIdentifier:CGTAMainStoryboardDetailViewControllerIdentifier];
    
    detailViewController.image = [CGTAImagesCatalog usaImage];
    // ... also, we have no guarantee that this view controller is an instance of CGTADetailViewController, thus accessing the .image property may case another error.
    [self.navigationController pushViewController:detailViewController animated:YES];
#else
    
#if 0
    // Here is example of a crash that might happen (especially if we reorganize our storyboards):
    storyboard = [UIStoryboard storyboardWithName:CGTAMainStoryboardName bundle:nil];
    detailViewController = [storyboard instantiateViewControllerWithIdentifier:CGTAUberModeStoryboardDetailViewControllerIdentifier];
    // the above will crash because of the discrepency between cgtaMAINstoryboardname and cgtaUBERMODEstoryboarddetailveiwcontrolleridentifier
    // the compiler will never catch these kind of mistakes. Unless we use Uber Mode...
#endif
    
    // Then really, why not use class methods?
    detailViewController = [CGTAMainStoryboard instantiateDetailViewController];
    // ... two lines became one, guaranteeing the previous error will never happen,
    
    detailViewController.image = [CGTAImagesCatalog usaImage];
    // ... also notice how this returns a CGTADetailViewController, rather than an id, so we can be assured that .image is a valid property!
    [self.navigationController pushViewController:detailViewController animated:YES];
#endif
}

- (IBAction)performTapped:(id)sender
{
#ifndef UBER_MODE
    // Initial version: full of strings that you have to type correctly!
    // Misspell any of these and your app will not work as expected.
    //[self performSegueWithIdentifier:@"Tap on Flag" sender:nil];

    // New version: get the properly compiler-checked spelling from the storyboard.
    [self performSegueWithIdentifier:CGTAMainStoryboardTapOnFlagIdentifier sender:nil];
#else
    
    // But really, why not use class methods?
    [self performTapOnFlagSegue];
#endif
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
#ifndef UBER_MODE
    CGTAFlagCollectionViewCell *cell = (CGTAFlagCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:CGTAMainStoryboardImageCellIdentifier forIndexPath:indexPath];
#else
    CGTAFlagCollectionViewCell *cell = [self dequeueImageCellForIndexPath:indexPath ofCollectionView:collectionView];
#endif
    cell.imageView.image = self.flagImages[indexPath.item];
    return cell;
}

@end


@implementation CGTAFlagCollectionViewCell
@end
