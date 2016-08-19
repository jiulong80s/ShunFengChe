//
//  LocManager.h
//  KKMYForU
//
//  Created by 黄磊 on 14-2-20.
//  Copyright (c) 2014年 Rogrand. All rights reserved.
//  位置信息管理

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <AMapSearchKit/AMapSearchAPI.h>
#import "LocInfoModel.h"
#import "AddrInfoModel.h"


typedef void (^LocManagerBlock)(BOOL isSucceed, AddrInfoModel *curLocInfo, NSError *error);

@interface LocManager : NSObject <AMapSearchDelegate, CLLocationManagerDelegate>


/** 当前定位位置信息 */
@property (nonatomic, strong) AddrInfoModel *curLocInfo;
/** 当前所选择的地址信息 */
@property (nonatomic, strong) AddrInfoModel *curAddrInfo;

+ (LocManager *)shareInstant;

/** 检查定位状态，如果定位为开启会弹窗提示，YES-开启；NO-未开启*/
+ (BOOL)checkLocationStatus;

/** 开始更新定位位置信息, 不需要调用stopUpdataLocation来停止更新, 回调一次之后会自动停止 */
- (void)startUpdateLocationCompletion:(LocManagerBlock)completion;


/** 根据经纬度搜索对应地址信息, 仅适用于地图经纬度 */
- (void)searchReGeocodeWithLocation:(CLLocation *)location completion:(LocManagerBlock)completion;

/** 网页获取位置信息 */
- (NSDictionary *)webGetLocInfo;

@end
