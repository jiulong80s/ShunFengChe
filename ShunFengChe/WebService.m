//
//  WebService.m
//  KKMYForU
//
//  Created by Zhiyong on 13-11-4.
//  Copyright (c) 2013年 ags. All rights reserved.
//

#import "WebService.h"
#import "MBProgressHUD.h"
#import "DeviceHelper.h"
#import "AppDelegate.h"
#import "Utils.h"
#import "JSONKit.h"

#define REQUEST_TIMEOUT 30
#define UPLOAD_TIMEOUT 60
#define DOWNLOAD_TIMEOUT 60

static NSString *requestString = nil;

@interface WebService ()

+ (ResultModel *)getResultWithString:(NSString *)aString
                         returnClass:(Class)returnClass
                            andError:(NSError**)err;


@end


@implementation WebService


#pragma 发起POST请求
+ (void)startRequest:(NSString *)action
                body:(NSString *)body
         returnClass:(Class)returnClass
             success:(RequestSuccessBlock)sblock
             failure:(RequestFailureBlock)fblock
{
    
    // 开发时使用本地数据，如需使用网络数据，请在Constant.h中注掉该定义
#ifdef USELOCALDATA
    NSString *receiveStr = (NSString *)[[[LocalData shareInstant] objectForKey:action] objectForKey:@"receive"];
    NSLog(@"...>>>...received data:%@", receiveStr);
    NSError *err = nil;
    ResultModel *result = nil;
    if (receiveStr)
    {
        result = [WebService getResultWithString:receiveStr
                                     returnClass:returnClass
                                        andError:&err];
        
        
    }
    if (err)
    {
        // 数据解析错误，出现该错误说明与服务器接口对应出了问题
        LogDebug(@"JSON Parse Error: %@\n", err);
        if (fblock)
        {
            fblock(nil, err);
        }
    }
    else
    {
        if (result)
        {
            if (sblock)
            {
                sblock(nil, result);
            }
        }
        else
        {
            err = [[NSError alloc] initWithDomain:@"本地没有保存该接口的假数据" code:-1000 userInfo:nil];
            if (fblock)
            {
                fblock(nil, err);
            }
        }
    }
    return;
#endif

	NSDictionary *aSendDic = [WebService getFinalRequestData:body];
	// 拼接请求url
    NSString *pathUrl = [NSString stringWithFormat:@"%@%@.do", kBaseUrl, action];
    LogTrace(@"...>>>...requestUrl: %@\n", pathUrl);
    LogInfo(@"...>>>...requestData: dataJson=%@\n", aSendDic[@"dataJson"]);
    
    AFHTTPSessionManager *manager=[AFHTTPSessionManager manager];
    
    manager.requestSerializer=[AFHTTPRequestSerializer serializer];
    manager.responseSerializer=[AFHTTPResponseSerializer serializer];
    [manager.requestSerializer setTimeoutInterval:REQUEST_TIMEOUT];
	//添加 User-Agent   KKMY_U 版本号
	NSString* userAgent = [NSString httpHeaderAgent];
	if (userAgent) {
		[manager.requestSerializer  setValue:userAgent forHTTPHeaderField:@"User-Agent"];
	}
	[manager POST:pathUrl
	   parameters:aSendDic
		 progress:^(NSProgress *uploadProgress){}
		  success:^(NSURLSessionTask *task, id responseObject) {
        // 请求成功
        id response = [manager.responseSerializer responseObjectForResponse:task.response data:responseObject error:nil];
		NSString *responseStr = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
		LogInfo(@"...>>>...receiveData = %@", responseStr);
        NSError *err = nil;
        // 解析json
		ResultModel *result = [WebService getResultWithString:responseStr
                                                  returnClass:returnClass
                                                     andError:&err];
        
        //sblock(response);
        if (err) {
            // 数据解析错误，出现该错误说明与服务器接口对应出了问题
            LogDebug(@"...>>>...JSON Parse Error: %@\n", err);
            if (fblock) {
                fblock(nil, err);
            }
            
        } else {
            if (sblock) {
                sblock(task, result);
            }
        }
        
    } failure:^(NSURLSessionTask *task, NSError *error) {
        // 请求失败
        if (fblock) {
            fblock(task, error);
        }
    }];
    
}
+ (void)startRequestForUpload:(NSString *)action
                         body:(NSString *)body
                     filePath:(NSString *)path
                  returnClass:(Class)returnClass
                      success:(RequestSuccessBlock)sblock
                      failure:(RequestFailureBlock)fblock
{
    
    // 拼接发送数据
	NSDictionary *aSendDic = [WebService getFinalRequestData:body];
	
    // 拼接请求url
    NSString *pathUrl = [NSString stringWithFormat:@"%@/%@.do", kBaseUrl, action];
    LogTrace(@"...>>>...requestUrl:%@\n", pathUrl);
    LogInfo(@"...>>>...requestData:%@\n", body);
    
    AFHTTPSessionManager *manager=[AFHTTPSessionManager manager];
    manager.requestSerializer=[AFHTTPRequestSerializer serializer];
    manager.responseSerializer=[AFHTTPResponseSerializer serializer];
    LogInfo(@"本地音频文件全路径:%@", path);
	//添加 User-Agent 后面追加 KKMY_U 版本号
	NSString* userAgent = [NSString httpHeaderAgent];
	if (userAgent) {
		[manager.requestSerializer  setValue:userAgent forHTTPHeaderField:@"User-Agent"];
	}
	
    [manager POST:pathUrl parameters:aSendDic constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        NSData *audioData = [NSData dataWithContentsOfFile:path];
        //[formData appendPartWithFileData:audioData name:[[path lastPathComponent] stringByDeletingPathExtension] fileName:[path lastPathComponent] mimeType:@"audio/speex"];
        NSString *mineType = @"audio/speex";
        if ([path hasSuffix:@"png"] || [path hasSuffix:@"jpg"]) {
            mineType = @"image/jpg";
        }
        if (audioData) {
            [formData appendPartWithFileData:audioData name:@"fileData" fileName:[path lastPathComponent] mimeType:mineType];
        }
    }progress:^(NSProgress *uploadProgress){}
	success:^(NSURLSessionTask *task, id responseObject) {
        // 请求成功
			id response = [manager.responseSerializer responseObjectForResponse:task.response data:responseObject error:nil];
			NSString *responseStr = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
			LogInfo(@"...>>>...receiveData = %@", responseStr);
        NSError *err = nil;
        
        ResultModel *result = [WebService getResultWithString:responseStr
                                                  returnClass:returnClass
                                                     andError:&err];
			if (err)
        {
            // 数据解析错误，出现该错误说明与服务器接口对应出了问题
            LogDebug(@"...>>>...JSON Parse Error: %@\n", err);
            if (fblock)
            {
                fblock(nil, err);
            }
        }
        else
        {
            if (sblock)
            {
                sblock(task, result);
            }
        }
        
    } failure:^(NSURLSessionTask *task, NSError *error) {
        // 请求失败
        LogError(@"...>>>...Network error: %@\n", [task error]);
        if (fblock)
        {
            fblock(task, error);
        }
        
    }];
    
}

/** 多文件上传 */
+ (void)startUploadFiles:(NSString *)action
                    body:(NSString *)body
                   files:(NSArray *)files
             returnClass:(Class)returnClass
                 success:(RequestSuccessBlock)sblock
                 failure:(RequestFailureBlock)fblock
{
    
    // 拼接发送数据
    NSDictionary *aSendDic = [self getFinalRequestData:body];
    
    // 拼接请求url
    NSString *pathUrl = [NSString stringWithFormat:@"%@%@.do", kBaseUrl, action];
    LogTrace(@"...>>>...requestUrl:%@\n", pathUrl);
    LogInfo(@"...>>>...requestData:%@\n", body);
    
    AFHTTPSessionManager *manager=[AFHTTPSessionManager manager];
    manager.requestSerializer=[AFHTTPRequestSerializer serializer];
    manager.responseSerializer=[AFHTTPResponseSerializer serializer];
    [manager.requestSerializer setTimeoutInterval:UPLOAD_TIMEOUT];
	
	//添加 User-Agent 后面追加 KKMY_U 版本号
	NSString* userAgent = [NSString httpHeaderAgent];
	if (userAgent) {
		[manager.requestSerializer  setValue:userAgent forHTTPHeaderField:@"User-Agent"];
	}
	
    [manager POST:pathUrl parameters:aSendDic constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        for (NSString *filePath in files) {
            LogInfo(@"本地文件全路径:%@", filePath);
            NSData *audioData = [NSData dataWithContentsOfFile:filePath];
            // 文件类型判断，需要优化
            NSString *mineType = @"audio/speex";
            if ([filePath hasSuffix:@"png"] || [filePath hasSuffix:@"jpg"]) {
                mineType = @"image/jpg";
            }
            if (audioData) {
                [formData appendPartWithFileData:audioData name:@"fileData" fileName:[filePath lastPathComponent] mimeType:mineType];
            }
        }
        
	}progress:^(NSProgress *uploadProgress){}
	success:^(NSURLSessionTask *task, id responseObject) {
        // 请求成功
			id response = [manager.responseSerializer responseObjectForResponse:task.response data:responseObject error:nil];
			NSString *responseStr = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
			LogInfo(@"...>>>...receiveData = %@", responseStr);
			NSError *err = nil;
			
			ResultModel *result = [WebService getResultWithString:responseStr
																								returnClass:returnClass
																									 andError:&err];
			
        if (err) {
            // 数据解析错误，出现该错误说明与服务器接口对应出了问题
            LogDebug(@"...>>>...JSON Parse Error: %@\n", err);
            if (fblock) {
                fblock(nil, err);
            }
        } else {
            if (sblock) {
                sblock(task, result);
            }
        }
        
    } failure:^(NSURLSessionTask *task, NSError *error) {
        // 请求失败
        LogError(@"...>>>...Network error: %@\n", [task error]);
        if (fblock) {
            fblock(task, error);
        }
        
    }];
}


/** 单个文件下载 */
+ (void)startDownload:(NSString *)remotePath
         withSavePath:(NSString *)localPath
           completion:(void (^)(BOOL isSucceed, NSString *message))completion
        progressBlock:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))progressBlock
{
    if (completion == nil) {
        completion = ^(BOOL isSucceed, NSString *message) {};
    }
    
    NSString *remoteFilePath = [NSString isFullUrl:remotePath];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:remoteFilePath]];
	NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
	config.timeoutIntervalForRequest = DOWNLOAD_TIMEOUT;
	AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:config];
	
	//添加 User-Agent 后面追加 KKMY_U 版本号
	NSString* userAgent = [NSString httpHeaderAgent];
	if (userAgent) {
		[request  setValue:userAgent forHTTPHeaderField:@"User-Agent"];
	}
	
	NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
		return [NSURL fileURLWithPath:localPath];;
	} completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
		if (error.code==200 || !error) {
			LogInfo(@"...>>>...Successfully downloaded file to %@\n", filePath);
			completion(YES, @"下载成功");
		}else
		{
			completion(NO,@"下载失败");
		}
	}];
	[downloadTask resume];
}

/** 下载分享图片 */
+ (void)downloadShareImg:(NSString *)imgUrl
{
    NSString *remoteUrl = [NSString isFullUrl:imgUrl];
    NSString *localUrl = [[NSString getTempLocation] stringByAppendingPathComponent:remoteUrl.md5];
    if (![[NSFileManager defaultManager] fileExistsAtPath:localUrl]) {
        [WebService startDownload:remoteUrl
                     withSavePath:localUrl
                       completion:^(BOOL isSucceed, NSString *message) {
                           if (isSucceed) {
                               LogInfo(@"download sharePic succeed");
                           } else {
                               LogError(@"%@", message);
                           }
                       }
                    progressBlock:nil];
    }
}
//对数据处理获取 mac 值，并拼接好
+(NSDictionary *)getFinalRequestData:(NSString *)body{
	// 拼接发送数据
	NSMutableDictionary *aSendDic = [self getWholeRequestData:body];
	
	/*head部分转成json串 + body部分转成json串 + "kkmy" 做md5，取md5加密结果的末尾8个字符*/
	NSMutableString *appendStr = [NSMutableString stringWithString:[WebService getHeadString]];
	if (!body || body.length==0) {
		[appendStr appendString:@"{}kkmy"];
	}else{
		[appendStr appendString:body];
		[appendStr appendString:@"kkmy"];
	}
	NSString *md5Str = [appendStr md5];
	NSString *mac = [md5Str substringFromIndex:md5Str.length-8];
	NSString *dataJson = aSendDic[@"dataJson"];
	dataJson = [dataJson stringByReplacingOccurrencesOfString:@"\"mac\":\"\"" withString:[NSString stringWithFormat:@"\"mac\":\"%@\"",mac]];
	[aSendDic setObject:dataJson forKey:@"dataJson"];
	return aSendDic;
}
// 拼装 request data
+ (NSMutableDictionary *)getWholeRequestData:(NSString *)requestBody
{
    // 拼接发送数据
    NSString *aSendData = [WebService getRequestString];
    if (requestBody == nil||requestBody.length==0) {
        requestBody = @"{}";
    }
    aSendData = [aSendData stringByReplacingOccurrencesOfString:@"{body}" withString:requestBody];
    return [NSMutableDictionary dictionaryWithObject:aSendData forKey:@"dataJson"];
    
}

+ (NSString *)getRequestString
{
    if (requestString == nil)
    {
        // 拼接发送数据
        NSString *aSendData = [kSendData stringByReplacingOccurrencesOfString:@"{mac}" withString:@"\"\""];
		aSendData = [aSendData stringByReplacingOccurrencesOfString:@"{head}"
														 withString:[WebService getHeadString]];
        requestString = [[NSString alloc] initWithString:aSendData];
        LogInfo(@"=====[RequestData]=====: %@", requestString);
    }
    return requestString;
}

+ (NSString *)getHeadString{
	NSString *iOSVersion = [NSString stringWithFormat:@"\"%@\"", [DeviceHelper getCurrentIOSVersion]];
	NSString *imei = [NSString stringWithFormat:@"\"%@\"", [DeviceHelper getDeviceID]];
	NSString *headerString = [kSendHeader stringByReplacingOccurrencesOfString:@"{terminalstate}" withString:kTerminalState];
	headerString = [headerString stringByReplacingOccurrencesOfString:@"{sysVersion}" withString:iOSVersion];
	headerString = [headerString stringByReplacingOccurrencesOfString:@"{appVersion}" withString:[NSString stringWithFormat:@"\"%@\"", kClientVersionShort]];
	headerString = [headerString stringByReplacingOccurrencesOfString:@"{imei}" withString:imei];
	headerString = [headerString stringByReplacingOccurrencesOfString:@"{appType}" withString:kAppType];
	headerString = [headerString stringByReplacingOccurrencesOfString:@"{appSys}" withString:kAppSys];
	headerString = [headerString stringByReplacingOccurrencesOfString:@"{channel}" withString:kChannel];
	return headerString;
}
// 从字符串转换成ResultModel
+ (ResultModel *)getResultWithString:(NSString *)aString
                         returnClass:(Class)returnClass
                            andError:(NSError**)err
{
    
    @try {
        RespondModel *aRespond = [[RespondModel alloc] initWithString:aString error:nil];
        NSDictionary *body = [aRespond.body copy];
        ResultModel *result = [[ResultModel alloc] init];
        result.code = [body objectForKey:@"code"];
        if (body) {//!< 从城市列表选择类似台湾，香港时，有可能为空
            result.message = [NSString stringWithString:[body objectForKey:@"message"]];

        }
        // 如果状态码不为0,则直接返回,不再解析后面的数据
        if (![result.code isEqualToString:@"000000"])
        {
            result.result = body[@"result"];
            return result;
        }
        if (returnClass == nil) {
            result.result = [body objectForKey:@"result"];
            return result;
        }
        // 判断返回数据是否正常,先判断code和message即可
        if ([[body objectForKey:@"result"] isKindOfClass:[NSDictionary class]])
        {   // result返回字典类型数据
            LogInfo(@"[NSDictionary class]");
            if ([body objectForKey:@"result"] && returnClass)
            {
                result.result = [[returnClass alloc] initWithDictionary:[body objectForKey:@"result"] error:err];
			}else{
				result.result = [body objectForKey:@"result"];
			}
        }
        else if ([[body objectForKey:@"result"] isKindOfClass:[NSString class]])
        { // result返回字串类型数据
            LogInfo(@"[NSString class]");
            if ([body objectForKey:@"result"] == nil || [[body objectForKey:@"result"] isEqualToString:@""] == YES)
            {
                result.result = nil;
            } else {
                result.result = [body objectForKey:@"result"];
            }
        }else if ([[body objectForKey:@"result"] isKindOfClass:[NSNumber class]])
        {
            LogInfo(@"[NSNumber class]");
            if ([body objectForKey:@"result"] == nil)
            {
                result.result = nil;
            } else {
                result.result = [body objectForKey:@"result"];
            }
        }
        else if ([[body objectForKey:@"result"] isKindOfClass:[NSArray class]] || [[body objectForKey:@"result"] isKindOfClass:[NSMutableArray class]])
        {  // result返回数组类型数据
            LogInfo(@"[NSArray class]");
            if ([body objectForKey:@"result"] && returnClass)
            {
                NSArray *array = [body objectForKey:@"result"];
                if (array != nil && array.count > 0)
                {
                    NSMutableArray *resultArr = [[NSMutableArray alloc] init];
                    for (int i = 0; i < array.count; i++)
                    {
                        NSDictionary *dic = [array objectAtIndex:i];
                        [resultArr addObject:[[returnClass alloc] initWithDictionary:dic error:err]];
                    }   // for
                    result.result = resultArr;
                }
                else
                {
                    result.result = nil;
                }
            }
        }
        return result;
    }
    @catch (NSException *exception)
    {
        LogDebug(@"%@", exception);
        *err = [[NSError alloc] initWithDomain:exception.reason code:-500 userInfo:exception.userInfo];
        return nil;
    }
    @finally {
        //
    }
    
}


@end
