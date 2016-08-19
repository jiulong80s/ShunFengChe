//
//  WebService.h
//  KKMYForU
//
//  Created by Zhiyong on 13-11-4.
//  Copyright (c) 2013年 ags. All rights reserved.
//  网络请求类

#import <Foundation/Foundation.h>
#import "Utils.h"
#import "AFNetworking.h"
#import "RespondModel.h"
#import "ResultModel.h"

//操作成功（网络请求成功，返回值Success = true,两个条件同时成立，才会回调该方法）
typedef void (^RequestSuccessBlock)(NSURLSessionTask *task, ResultModel *result);
//操作失败（网络原因的失败，或者返回值Success != true则执行下面的回调）
typedef void (^RequestFailureBlock)(NSURLSessionTask *task, NSError *error);


@interface WebService : NSObject


/**
 *	@brief	post请求接口
 *
 *	@param 	action 	请求的接口名称
 *	@param 	body 	请求的body数据
 *	@param 	returnClass 	就收返回数据的model
 *	@param 	sblock 	请求成功回调
 *	@param 	fblock 	请求失败回调
 *
 *	@return	void
 */
+ (void)startRequest:(NSString *)action
                body:(NSString *)body
         returnClass:(Class)returnClass
             success:(RequestSuccessBlock)sblock
             failure:(RequestFailureBlock)fblock;


/**
 *	@brief	多文件上传接口
 *
 *	@param 	action          接口名称
 *	@param 	body            请求body数据
 *	@param 	filePath           请求文件列表，eg：@"本地文件全路径"
 *	@param 	returnClass 	接收返回数据的model
 *	@param 	sblock          成功回调
 *	@param 	fblock          失败回调
 *
 *	@return	void
 */
+ (void)startRequestForUpload:(NSString *)action
                         body:(NSString *)body
                     filePath:(NSString *)path
                  returnClass:(Class)returnClass
                      success:(RequestSuccessBlock)sblock
                      failure:(RequestFailureBlock)fblock;
/**
 *	@brief	多文件上传接口
 *
 *	@param 	action          接口名称
 *	@param 	body            请求body数据
 *	@param 	files           请求文件列表，eg：@[@"本地文件全路径", @"本地文件全路径"]
 *	@param 	returnClass 	接收返回数据的model
 *	@param 	sblock          成功回调
 *	@param 	fblock          失败回调
 *
 *	@return	void
 */
+ (void)startUploadFiles:(NSString *)action
                    body:(NSString *)body
                   files:(NSArray *)files
             returnClass:(Class)returnClass
                 success:(RequestSuccessBlock)sblock
                 failure:(RequestFailureBlock)fblock;

/**
 *	@brief	单个文件下载
 *
 *	@param 	remotePath      下载文件的远程路径
 *	@param 	localPath       下载文件的本地保存路径
 *	@param 	completion      请求完成的回调
 *	@param 	progressBlock 	下载进度回调: bytesRead-已读子节; totalBytesRead-总字节; totalBytesExpectedToRead-未读子节
 *
 *	@return	void
 */
+ (void)startDownload:(NSString *)remotePath
         withSavePath:(NSString *)localPath
           completion:(void (^)(BOOL isSucceed, NSString *message))completion
        progressBlock:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))progressBlock;

/** 下载分享图片 */
+ (void)downloadShareImg:(NSString *)imgUrl;

+ (ResultModel *)getResultWithString:(NSString *)aString
                         returnClass:(Class)returnClass
                            andError:(NSError**)err;

//对数据处理获取 mac 值，并拼接好
+(NSDictionary *)getFinalRequestData:(NSString *)body;
@end
