//
//  LocManager.m
//  KKMYForU
//
//  Created by 黄磊 on 14-2-20.
//  Copyright (c) 2014年 Rogrand. All rights reserved.
//

#import "LocManager.h"
#import "MapLocationKit.h"
#import "AppDelegate.h"
#import "CityModel.h"
#import "DBManager.h"
#import "JZLocationConverter.h"
#import <AMapSearchKit/AMapSearchKit.h>
#import "JLAlertView.h"

#define SEARCH_TIMEOUT 30
#define EARTH_RADIUS 6378137.0
#define Min_Minute (60 * 3)
#define Min_Distance 100.0

static LocManager *s_locManager = nil;

@interface LocManager ()
{
	CLLocationManager *_locationManager;
}
@property (nonatomic, strong) AMapSearchAPI *search;
@property (nonatomic, strong) CLLocation *curCLLocation;

@property (nonatomic, strong) AMapReGeocodeSearchRequest *reGeocodeRequest;

@property (nonatomic, strong) NSMutableDictionary *dicRequest;          // 想高德获取地址信息的请求列表
@property (nonatomic, strong) NSMutableArray *arrLocCallback;           // 获取当前位置信息的block回调

// 以下是为了防止获取到经纬度后仍然提示跟新失败的问题，如果以后确定不会出现这种情况之后可以去掉
@property (nonatomic, assign) BOOL willUpdataLocationFailed;            // 是否更新定位失败
@property (nonatomic, strong) NSError *errorUpdataLocationFailed;       // 更新定位失败的error
@property (nonatomic, assign) BOOL isUpdatingLocation;                  // 是否正在跟新位置信息


@end


@implementation LocManager

@synthesize curAddrInfo = _curAddrInfo;

+ (LocManager *)shareInstant
{
    
    static dispatch_once_t once_patch;
    dispatch_once(&once_patch, ^()
    {
        s_locManager = [[LocManager alloc] init];
    });
    
  
    return s_locManager;
}

- (id)init
{
    self = [super init];
    if (self) {
		AMapSearchServices *services = [AMapSearchServices sharedServices];//GaoDe_APIKEY
		[services setApiKey:GaoDe_APIKEY];
        self.search = [[AMapSearchAPI alloc] init];
		self.search.delegate = self;
		self.search.language = AMapSearchLanguageZhCN;
        self.search.timeout = SEARCH_TIMEOUT / 2;
        self.dicRequest = [[NSMutableDictionary alloc] init];
        self.arrLocCallback = [[NSMutableArray alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appStatusActive) name:kAppBecomeActive object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appStatusActive) name:kAppGetNetwork object:nil];
    }
    return self;
}

- (void)setCurAddrInfo:(AddrInfoModel *)curAddrInfo
{
    if (curAddrInfo == nil) {
        return;
    }
    _curAddrInfo = curAddrInfo;
    [[NSUserDefaults standardUserDefaults] setObject:[_curAddrInfo toDictionary] forKey:kCurAddrInfo];
}

- (AddrInfoModel *)curAddrInfo
{
    if (_curAddrInfo == nil) {
        NSDictionary *aDic = [[NSUserDefaults standardUserDefaults] objectForKey:kCurAddrInfo];
        @try {
            NSError *error = nil;
            AddrInfoModel *aAddr = [[AddrInfoModel alloc] initWithDictionary:aDic error:&error];
            if (error == nil) {
				if(!aAddr.cityCode)aAddr.cityCode = aAddr.areaCode;
                _curAddrInfo = aAddr;
            } else {

            }
        }
        @catch (NSException *exception) {
            LogError(@"%@", exception);
        }
        @finally {
             return _curAddrInfo;
        }
    }
    return _curAddrInfo;
}

#pragma mark - Notification Receive

- (void)appStatusActive
{
    [self startUpdateLocationCompletion:^(BOOL isSucceed, AddrInfoModel *curLocInfo, NSError *error) {
        
    }];
}

#pragma mark - Public

+ (BOOL)checkLocationStatus
{
    BOOL canGetLocation = NO;
    if ([CLLocationManager locationServicesEnabled]) {
        CLAuthorizationStatus authorStatus = [CLLocationManager authorizationStatus];
        if ((authorStatus == kCLAuthorizationStatusAuthorized
             || authorStatus == kCLAuthorizationStatusNotDetermined)) {
            // 定位功能可用
            canGetLocation = YES;
        } else if (authorStatus == kCLAuthorizationStatusDenied){
            // 定位未授权
            LogInfo(@"定位功能不可用，提示用户或忽略");
        } else {
            if (__CUR_IOS_VERSION >= __IPHONE_8_0) {
                if (authorStatus == kCLAuthorizationStatusAuthorizedAlways ||
                    authorStatus == kCLAuthorizationStatusAuthorizedWhenInUse) {
                    canGetLocation = YES;
                }
            }
        }
    } else {
        // 定位服务未开启
    }
    
    if (!canGetLocation) {
        JLAlertView *alert=[[JLAlertView alloc]initWithTitle:@"提示" detailText:@"请在系统设置中开启定位服务" customView:nil cancelButtonTitle:@"我知道了" otherButtonTitles:nil];
        [alert showWithBlock:^(NSInteger index) {
            
        }];
        }
    
    return canGetLocation;
}


- (NSDictionary *)webGetLocInfo
{
    if (self.curAddrInfo) {
        NSDictionary *aDic = @{@"latitude":_curAddrInfo.addressLatitude,
                               @"longitude": _curAddrInfo.addressLongitude,
                               @"regionCode":_curAddrInfo.areaCode,
                               @"addr":_curAddrInfo.fullAddrName};
        return aDic;
    }
    return  nil;
}

- (void)startUpdateLocationCompletion:(LocManagerBlock)completion
{
    // 非空判断
    if (completion == NULL) {
        completion = ^(BOOL isSucceed, AddrInfoModel *curLocInfo, NSError *error) {};
    }
    
    // isPersistent:是否持续跟新
    NSDictionary *aDic = @{@"isPersistent":@NO,
                           @"callback":completion};
    [_arrLocCallback addObject:aDic];
    [self startUpdateLocation];
}

- (void)startMonitorLocationCompletion:(LocManagerBlock)completion
{
    // 非空判断
    if (completion == NULL) {
        completion = ^(BOOL isSucceed, AddrInfoModel *curLocInfo, NSError *error) {};
    }
    
    // isPersistent:是否持续跟新
    NSDictionary *aDic = @{@"isPersistent":@YES,
                           @"callback":completion};
    [_arrLocCallback addObject:aDic];
    [self startUpdateLocation];
}

- (void)startUpdateLocation
{
    LogTrace(@"Start Updata Location");
    if (_locationManager == nil) {
        _locationManager = [[CLLocationManager alloc] init];
        [_locationManager setDelegate:self];
        [_locationManager setDistanceFilter:kCLDistanceFilterNone];
        [_locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
    }
    if (!_isUpdatingLocation) {
        [_locationManager startUpdatingLocation];
        if (__CUR_IOS_VERSION >= __IPHONE_8_0) {
            [_locationManager requestWhenInUseAuthorization];
//        [_locationManager requestAlwaysAuthorization];
        }
    }
    _isUpdatingLocation = YES;

    _curCLLocation = nil;
}

/** 停止更新定位信息, 这将停止所有的定位更新, 请谨慎使用 */
- (void)stopUpdataLocation
{
    LogTrace(@"Stop Updata Location");
    if (!_isUpdatingLocation) {
        LogTrace(@"Updata Location Is Already Stop");
        return;
    }
    if (_locationManager) {
        _isUpdatingLocation = NO;
        [_locationManager stopUpdatingLocation];
//        _locationManager = nil;
    }
    [_arrLocCallback removeAllObjects];
    [MapLocationKit closeSqlite];
}

#pragma mark -For GPS
/** 根据经纬度搜索对应地址信息, 仅适用于GPS经纬度 */
- (void)searchByGPSReGeocodeWithLocation:(CLLocation *)location completion:(LocManagerBlock)completion
{
    [self searchByGPSReGeocodeWithLocation:location isLocation:NO completion:completion];
}

- (void)searchByGPSReGeocodeWithLocation:(CLLocation *)location isLocation:(BOOL)isLocation completion:(LocManagerBlock)completion
{
    CLLocationCoordinate2D newLocation2D=[MapLocationKit zzTransGPS:location.coordinate];
    CLLocationCoordinate2D gcjPt = [JZLocationConverter wgs84ToGcj02:location.coordinate];
    CLLocation *aLocation1 = [[CLLocation alloc] initWithLatitude:gcjPt.latitude longitude:gcjPt.longitude];
    LogTrace(@"GPS location : %@  ", location);
    LogTrace(@"Map location1 : (latitude = %f, longitude = %f) ", newLocation2D.latitude, newLocation2D.longitude);
    LogTrace(@"Map location2 : (latitude = %f, longitude = %f) ", gcjPt.latitude, gcjPt.longitude);
    [self searchReGeocodeWithLocation:aLocation1 isLocation:isLocation completion:completion];
}

#pragma mark -For Map
- (void)searchReGeocodeWithLocation:(CLLocation *)location completion:(LocManagerBlock)completion
{
    [self searchReGeocodeWithLocation:location isLocation:NO completion:completion];
}

- (void)searchReGeocodeWithLocation:(CLLocation *)location isLocation:(BOOL)isLocation  completion:(LocManagerBlock)completion
{
    // 非空判断
    if (completion == NULL) {
        completion = ^(BOOL isSucceed, AddrInfoModel *curLocInfo, NSError *error) {};
    }
    
    
    AddrInfoModel *tmpAddrInfo = [[AddrInfoModel alloc] init];
    tmpAddrInfo.addressLatitude = [NSNumber numberWithDouble:location.coordinate.latitude];
    tmpAddrInfo.addressLongitude = [NSNumber numberWithDouble:location.coordinate.longitude];
    
    // 判断网络状态
    if (![[AFNetworkReachabilityManager sharedManager] isReachable]) {
        // 无网络
        NSError *err = [[NSError alloc] initWithDomain:kNetworkErrorMsg code:kNetworkOffNet userInfo:nil];
        completion(NO, nil, err);
        if (isLocation) {
            [self locationCallbackIsSucceed:NO addrInfo:tmpAddrInfo error:err];
        }
        return;
    }
    
    if (isLocation) {
        // 当前经纬度
        if (_reGeocodeRequest != nil) {
            return;
        }
    }
    
    
    
    
    AMapReGeocodeSearchRequest *aRequest = [[AMapReGeocodeSearchRequest alloc] init];
//    aRequest.searchType = AMapSearchType_ReGeocode;
    aRequest.location = [AMapGeoPoint locationWithLatitude:[tmpAddrInfo.addressLatitude doubleValue] longitude:[tmpAddrInfo.addressLongitude doubleValue]];
    aRequest.radius = 1000;
    aRequest.requireExtension = YES;
    
    NSString *keyRequest = [NSString stringWithFormat:@"%ld", (long)aRequest.hash];
    NSDictionary *aDic = @{@"addrInfo":tmpAddrInfo,
                           @"callback":completion};
    [_dicRequest setObject:aDic forKey:keyRequest];
    LogInfo(@"%d", (int)aRequest.hash);
    
    if (isLocation) {
        _reGeocodeRequest = aRequest;
        tmpAddrInfo.isLocation = @YES;
    }
    
    // begin search
    [self.search AMapReGoecodeSearch:aRequest];
}




#pragma mark - Private


// 获取到经纬度对应的地址信息
- (void)searchGetLocationAddr:(AMapReGeocode *)addr forRequest:(AMapReGeocodeSearchRequest *)request
{
    
    NSString *keyRequest = [NSString stringWithFormat:@"%ld", (long)request.hash];
    
    AddrInfoModel *tmpAddrInfo = nil;
    LocManagerBlock aCallback = NULL;
    NSDictionary *aDic = [_dicRequest objectForKey:keyRequest];
    if (aDic) {
        tmpAddrInfo = aDic[@"addrInfo"];
        aCallback = aDic[@"callback"];
    }
    
    if (tmpAddrInfo == nil) {
        LogError(@"Code Error: There is no address info for this request");
        return;
    }
    
    // 处理地址数据
    tmpAddrInfo.fullAddrName = addr.formattedAddress;
    tmpAddrInfo.provinceName = addr.addressComponent.province;
    tmpAddrInfo.cityName = addr.addressComponent.city;
    tmpAddrInfo.districtName = addr.addressComponent.district;
    tmpAddrInfo.areaCode = addr.addressComponent.adcode;
    
    NSArray *arrAddr = [[DBManager shareInstance] queryParentCitiesWithCityCode:tmpAddrInfo.areaCode];
    for (int i=0, len=arrAddr.count; i < len; i++) {
        CityModel *areaInfo = arrAddr[i];
        switch (i) {
            case 0:
                tmpAddrInfo.provinceCode = areaInfo.cityCode;
                tmpAddrInfo.provinceName = areaInfo.cityName;
                break;
            case 1:
                tmpAddrInfo.cityCode = areaInfo.cityCode;
                tmpAddrInfo.cityName = areaInfo.cityName;
                break;
            case 2:
                tmpAddrInfo.regionCode = areaInfo.cityCode;
                tmpAddrInfo.districtName = areaInfo.cityName;
                break;
            default:
                break;
        }
        if (i == len - 1) {
            tmpAddrInfo.areaCode = areaInfo.cityCode;
            tmpAddrInfo.areaName = areaInfo.cityName;
        }
    }
    LogTrace(@"Get location : %@ ", tmpAddrInfo);
    
    // 开始回调
    // 对应请求回调
    if (aCallback) {
        aCallback(YES, tmpAddrInfo, nil);
    }
    
    if ([tmpAddrInfo.isLocation boolValue]) {
        // 当前经纬度回调
        _curLocInfo = tmpAddrInfo;
        [self locationCallbackIsSucceed:YES addrInfo:tmpAddrInfo error:nil];
    }
    
    [_dicRequest removeObjectForKey:keyRequest];
}

- (void)locationCallbackIsSucceed:(BOOL)isSucceed addrInfo:(AddrInfoModel *)addrInfo error:(NSError *)err
{
    NSMutableArray *arrRemain = [[NSMutableArray alloc] init];
    for (NSDictionary *aDic in _arrLocCallback) {
        NSNumber *isPersistent = aDic[@"isPersistent"];
        LocManagerBlock aCallback = aDic[@"callback"];
        if ([isPersistent boolValue]) {
            [arrRemain addObject:aDic];
        }
        if (aCallback) {
            aCallback(isSucceed, addrInfo, err);
        }
    }
    _arrLocCallback = arrRemain;
    if (_arrLocCallback.count == 0) {
        [self stopUpdataLocation];
    }
    _reGeocodeRequest = nil;
    
    //
    if (_willUpdataLocationFailed) {
        _willUpdataLocationFailed = NO;
        [self locationCallbackIsSucceed:NO addrInfo:nil error:_errorUpdataLocationFailed];
        _errorUpdataLocationFailed = nil;
    }
}


#pragma mark - AMapSearchDelegate

/*!
 @brief 逆地理编码 查询回调函数
 @param request 发起查询的查询选项(具体字段参考AMapReGeocodeSearchRequest类中的定义)
 @param response 查询结果(具体字段参考AMapReGeocodeSearchResponse类中的定义)
 */
- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response
{

    
    LogInfo(@"%d", (int)request.hash);
    AMapReGeocode *theReGoecode = response.regeocode;
    
    // 保存数据
    [self searchGetLocationAddr:theReGoecode forRequest:request];

}


- (void)searchRequest:(id)request didFailWithError:(NSError *)error
{
    LogError(@"Search Location Info Error : %@", error);
    NSString *keyRequest = [NSString stringWithFormat:@"%ld", (long)((NSObject *)request).hash];
    
    NSDictionary *aDic = [_dicRequest objectForKey:keyRequest];
    AddrInfoModel *tmpAddrInfo = nil;
    if (aDic) {
        tmpAddrInfo = aDic[@"addrInfo"];
        LocManagerBlock aCallback = aDic[@"callback"];
        if (aCallback) {
            aCallback(NO, tmpAddrInfo, error);
        }
    }
    
    if ([request isEqual:_reGeocodeRequest]) {
        [self locationCallbackIsSucceed:NO addrInfo:tmpAddrInfo error:error];
    }
    [_dicRequest removeObjectForKey:keyRequest];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusAuthorizedAlways ||
        status == kCLAuthorizationStatusAuthorizedWhenInUse ||
        status == kCLAuthorizationStatusAuthorized) {
        if (_isUpdatingLocation) {
//            [_locationManager startUpdatingLocation];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations
{
    if (locations.count >0)
    {
        CLLocation *newLocation = [locations objectAtIndex:0];
        if (_curCLLocation)
        {
            // How many seconds ago was this new location created?
            NSTimeInterval t = [[newLocation timestamp] timeIntervalSinceDate:[_curCLLocation timestamp]];

            // CLLocationManagers will return the last found location of the
            // device first, you don't want that data in this case.
            // If this location was made more than 3 minutes ago, ignore it.
            if (t < Min_Minute)
            {
                // This is cached data, you don't want it, keep looking
                double distance = gps2m(_curCLLocation.coordinate.latitude, _curCLLocation.coordinate.longitude, newLocation.coordinate.latitude, newLocation.coordinate.longitude);
                if (distance < Min_Distance)
                {
                    return;
                }
            }
        }
        _curCLLocation = newLocation;
        LogInfo(@"Did updata to location : latitude:%f, longitude:%f", newLocation.coordinate.latitude, newLocation.coordinate.longitude);
        [self searchByGPSReGeocodeWithLocation:_curCLLocation isLocation:YES completion:^(BOOL isSucceed, AddrInfoModel *curLocInfo, NSError *error) {

        }];
    }
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    LogInfo(@"latitude:%f, longitude:%f", newLocation.coordinate.latitude, newLocation.coordinate.longitude);
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
    LogError(@"Get Location Failed. Error : %@", error);
    if (_reGeocodeRequest != nil) {
        _willUpdataLocationFailed = YES;
        _errorUpdataLocationFailed = error;
    } else {
        [self locationCallbackIsSucceed:NO addrInfo:nil error:error];
    }
}

// 计算经纬度两点之间的距离
double gps2m(double lat_a, double lng_a, double lat_b, double lng_b)
{
    double radLat1 = (lat_a * M_PI / 180.0);
    double radLat2 = (lat_b * M_PI / 180.0);
    double a = radLat1 - radLat2;
    double b = (lng_a - lng_b) * M_PI / 180.0;
    double s = 2 * asin(sqrt(pow(sin(a / 2), 2)
                             + cos(radLat1) * cos(radLat2)
                             * pow(sin(b / 2), 2)));
    s = s * EARTH_RADIUS;
    s = floor(s * 10000 + 0.5) / 10000;
    return s;
}



@end
