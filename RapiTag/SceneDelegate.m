//
//  SceneDelegate.m
//  RapiTag
//
//  Created by Tim.Milne on 3/8/26.
//  Copyright © 2026 Tim.Milne. All rights reserved.
//

#import "SceneDelegate.h"

@implementation SceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached.
}

- (void)sceneDidBecomeActive:(UIScene *)scene{
    // Restart any tasks that were paused (or not yet started) while the scene was inactive. If the scene was previously in the background, optionally refresh the user interface.
}

- (void)sceneWillResignActive:(UIScene *)scene {
    // Sent when the scene is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the scene and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough scene state information to restore your scene to its current state in case it is disconnected later.
    // If your scene supports background execution, this method is called instead of sceneDidDisconnect: when the user quits.
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called when the scene is about to disconnect. Save data if appropriate. See also sceneDidEnterBackground:.
}

@end
