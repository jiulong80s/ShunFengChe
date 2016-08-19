//
//  InterfaceManager.m
//  KKMYForM
//
//  Created by Xia Zhiyong on 13-11-8.
//  Copyright (c) 2013年 Xia Zhiyong. All rights reserved.
//

#import "InterfaceManager.h"

#define SetObjForDic(dic,obj,key)	if(obj){[dic setObject:(obj) forKey:key];}

@implementation InterfaceManager


#pragma mark - Class Function

/** 统一接口请求 */
+ (void )startRequest:(NSString *)action
            describe:(NSString *)describe
                body:(NSString *)body
         returnClass:(Class)returnClass
          completion:(InterfaceManagerBlock)completion
{
    [WebService startRequest:action
						body:body
				 returnClass:returnClass
					 success:^(NSURLSessionTask *task, ResultModel *result)
	{
            [self succeedWithResult:result describe:describe callback:completion];
	}
					 failure:^(NSURLSessionTask *task, NSError *error)
	{
        [self failedWithError:error describe:describe callback:completion];
	}];
}

/** 统一上传接口请求 */
+ (void )startUpload:(NSString *)action
           describe:(NSString *)describe
               body:(NSString *)body
              files:(NSArray *)files
        returnClass:(Class)returnClass
         completion:(InterfaceManagerBlock)completion
{
    [WebService startUploadFiles:action body:body files:files returnClass:returnClass success:^(NSURLSessionTask *operation, ResultModel *result) {
        [self succeedWithResult:result describe:describe callback:completion];
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        [self failedWithError:error describe:error.localizedDescription callback:completion];
    }];
}

/** 单个文件上传 */
+ (void)uploadSingleFile:(NSString *)filePath completion:(InterfaceManagerBlock)completion
{
    NSString *describe = @"文件上传";
    [self startUpload:API_UPLOAD_SINGLE_FILE describe:describe body:nil files:@[filePath] returnClass:nil completion:completion];
}

/** 多文件上传 */
+ (NSString *)uploadFiles:(NSArray *)filePaths completion:(InterfaceManagerBlock)completion
{
    NSString *describe = @"多个文件上传";
    return [self startUpload:API_UPLOAD_FILES describe:describe body:nil files:filePaths returnClass:nil completion:completion];
}

/**
 *	@brief	请求成功数据处理
 *
 *	@param 	result      请求成功后返回的结构
 *	@param 	describe 	请求描述
 *	@param 	completion 	请求完成回调
 *
 *	@return	void
 */
+ (void)succeedWithResult:(ResultModel *)result
                 describe:(NSString *)describe
                 callback:(InterfaceManagerBlock)completion

{
    if (completion == nil) {
        completion = ^(BOOL isSucceed, NSString *message, id data) {};
    }
    if (![result.code isEqualToString:@"000000"]) {
        completion(NO, result.message, result);
    } else {
        NSString *succeedMessage = result.message;
        if (succeedMessage.length == 0 || [succeedMessage isEqualToString:@"操作成功"]) {
            succeedMessage = [describe stringByAppendingString:@"成功"];
        }
        completion(YES, succeedMessage, result.result);
    }
}

/**
 *	@brief	请求失败数据处理
 *
 *	@param 	error 	请求失败的错误
 *	@param 	describe 	请求描述
 *	@param 	completion 	请求完成回调
 *
 *	@return	void
 */
+ (void)failedWithError:(NSError *)error
               describe:(NSString *)describe
               callback:(InterfaceManagerBlock)completion

{
    if (completion == nil) {
        completion = ^(BOOL isSucceed, NSString *message, id data) {};
    }
    NSString *message = [describe stringByAppendingString:@"失败"];
    switch (error.code) {
        case kNetworkOffNet:
            message = kNetworkErrorMsg;
            break;
        case kCFURLErrorUnknown:
            message = @"连接失败或服务无响应";
            break;
        case kCFURLErrorCancelled:
            message = @"网络连接被取消";
            break;
        case kCFURLErrorBadURL:
            message = @"错误的连接地址";
            break;
        case kCFURLErrorTimedOut:
            message = @"网络超时";
            break;
        case kCFURLErrorUnsupportedURL:
            message = @"网络地址不被支持";
            break;
        case kCFURLErrorCannotFindHost:
        case kCFURLErrorCannotConnectToHost:
        case kCFURLErrorNetworkConnectionLost:
        case kCFURLErrorDNSLookupFailed:
        case kCFURLErrorNotConnectedToInternet:
        case kCFURLErrorRedirectToNonExistentLocation:
            message = @"无法连接到服务器";
            break;
        case kCFURLErrorBadServerResponse:
        case kCFURLErrorHTTPTooManyRedirects:
            message = @"连接失败或服务无响应";
            break;
        case kCFURLErrorResourceUnavailable:
            message = @"无效的资源";
            break;
        case kCFURLErrorUserCancelledAuthentication:
            message = @"连接失败或服务无响应";
            break;
        case kCFURLErrorUserAuthenticationRequired:
            message = @"连接失败或服务无响应";
            break;
        case kCFURLErrorZeroByteResource:
            message = @"连接失败或服务无响应";
            break;
        case kCFURLErrorCannotDecodeRawData:
            message = @"连接失败或服务无响应";
            break;
        case kCFURLErrorCannotDecodeContentData:
            message = @"连接失败或服务无响应";
            break;
        case kCFURLErrorCannotParseResponse:
            message = @"无法解析响应";
            break;
        case kCFURLErrorInternationalRoamingOff:
            message = @"网络漫游关闭";
            break;
        case kCFURLErrorCallIsActive:
            message = @"正在打电话中";
            break;
        case kCFURLErrorDataNotAllowed:
            message = @"数据不被允许";
            break;
        case kCFURLErrorRequestBodyStreamExhausted:
            message = @"连接失败或服务无响应";
            break;
        case kCFURLErrorFileDoesNotExist:
            message = @"文件不存在";
            break;
        case kCFURLErrorFileIsDirectory:
            message = @"请求文件是文件夹";
            break;
        case kCFURLErrorNoPermissionsToReadFile:
            message = @"无权读取文件";
            break;
        case kCFURLErrorDataLengthExceedsMaximum:
            message = @"数据长度超过最大值";
            break;
        default:
            break;
    }
    
    completion(NO, message, nil);
    
}
/*
+(void)getDeliverDetailWithOrderID:(NSNumber *)orderID withCompletion:(InterfaceManagerBlock)completion{
    NSString *describe = @"获取物流详情";
    NSMutableDictionary *sendDic = [NSMutableDictionary dictionary];
    SetObjForDic(sendDic, orderID, @"orderId");
    SetObjForDic(sendDic, [[UserManager shareInstant] getUserId], @"userId")
    [self startRequest:API_GET_DELIVER_DETAIL
              describe:describe
                  body:[sendDic convertToJsonString]
           returnClass:[LogisticsInfoModel class]
            completion:completion];
}*/
@end
