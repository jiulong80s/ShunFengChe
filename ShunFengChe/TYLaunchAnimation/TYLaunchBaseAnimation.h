//
//  TYLaunchBaseAnimation.h
//  TYLaunchAnimationDemo
//
//  Created by tanyang on 15/12/4.
//  Copyright © 2015年 tanyang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TYLaunchAnimationProtocol.h"

@interface TYLaunchBaseAnimation : NSObject<TYLaunchAnimationProtocol>

@property (nonatomic, assign) CGFloat duration;// duration time 持续时间
@property (nonatomic, assign) CGFloat delay;   // delay hide 延迟隐藏
@property (nonatomic, assign) UIViewAnimationOptions options;   //选项

@end
