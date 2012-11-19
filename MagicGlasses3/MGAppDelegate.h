//
//  MGAppDelegate.h
//  MagicGlasses2
//
//  Created by Roman Smirnov on 18.11.12.
//  Copyright (c) 2012 Roman Smirnov. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MGViewController;

@interface MGAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) MGViewController *viewController;

@end
