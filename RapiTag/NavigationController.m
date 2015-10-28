//
//  NavigationController.m
//  RapiTag
//
//  Created by Tim.Milne on 6/18/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import "NavigationController.h"

@interface NavigationController ()

@end

@implementation NavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
 */

#pragma mark - Orientation

// These are the only reason I have a NavigationController class, which is the parent controller of all others.
// If you remove these, the default orientations are portrait and left and right, and this object is not needed.
// To enable this:
//   - Verify the supported orientation entries are in the Info.plist file
//   - Check the appropriate orientation boxes under project general tab, deployment info
//   - Associate this object with the NavigationController in the Main.storyboard
// And you are good to go.

// For all orientations, you don't need to override these
/*
 - (BOOL)shouldAutorotate
 {
 return YES;
 }
 
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
 {
 // Return YES for supported orientations
 return YES;
 }
 */

// For all orientations, this will suffice.
-(UIInterfaceOrientationMask)supportedInterfaceOrientations{
    
    /*
     NSInteger orientationMask = 0;
     
     orientationMask |= UIInterfaceOrientationMaskLandscapeLeft;
     orientationMask |= UIInterfaceOrientationMaskLandscapeRight;
     orientationMask |= UIInterfaceOrientationMaskPortrait;
     orientationMask |= UIInterfaceOrientationMaskPortraitUpsideDown;
     
     return orientationMask;
     */
    
    // For all orientations, use this
    return UIInterfaceOrientationMaskAll;
}

@end
