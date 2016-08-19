//
//  InterfaceManager.h
//  KKMYForM
//
//  Created by Xia Zhiyong on 13-11-8.
//  Copyright (c) 2013年 Xia Zhiyong. All rights reserved.
//  接口管理类

#import <Foundation/Foundation.h>
#import "WebService.h"
#import "ResultModel.h"

typedef void (^InterfaceManagerBlock)(BOOL isSucceed, NSString *message, id data);


// 获取物流详情
//static NSString *const API_GET_DELIVER_DETAIL = @"/order/getDeliverDetail";


@interface InterfaceManager : NSObject

/**
 *	@brief	统一接口请求
 *
 *	@param 	action          接口名称
 *	@param 	describe        接口描述
 *	@param 	body            请求body
 *	@param 	returnClass 	接收的model
 *	@param 	completion      请求完成回调
 *
 *	@return	当前请求ID
 */
+ (void)startRequest:(NSString *)action
            describe:(NSString *)describe
                body:(NSString *)body
         returnClass:(Class)returnClass
          completion:(InterfaceManagerBlock)completion;

/**
 *	@brief	统一上传接口请求，多文件上传
 *
 *	@param 	action          接口名称
 *	@param 	describe        接口描述
 *	@param 	body            请求body
 *	@param 	files           请求文件列表，eg：@[@"本地文件全路径", @"本地文件全路径"]
 *	@param 	returnClass 	接收的model
 *	@param 	completion      请求完成回调
 *
 *	@return	当前请求ID
 */
+ (NSString *)startUpload:(NSString *)action
           describe:(NSString *)describe
               body:(NSString *)body
              files:(NSArray *)files
        returnClass:(Class)returnClass
         completion:(InterfaceManagerBlock)completion;


/**
 *	@brief	<已不再使用>单个文件上传，这里仅支持单个图片上传，上传完成后会返回临时储存路径
 *
 *	@param 	filePath 	需要上传文件的本地路径
 *	@param 	completion  请求完成回调，成功时会返回临时文件路径
 *
 *	@return	void
 */
+ (void)uploadSingleFile:(NSString *)filePath
              completion:(InterfaceManagerBlock)completion;

/**
 *	@brief	单个文件上传，这里仅支持单个图片上传，上传完成后会返回临时储存路径
 *
 *	@param 	filePaths 	需要上传文件的本地路径数组
 *	@param 	completion  请求完成回调，成功时会返回临时文件路径
 *
 *	@return	void
 */
+ (NSString *)uploadFiles:(NSArray *)filePaths
         completion:(InterfaceManagerBlock)completion;


/** 通用列表请求 */
+ (NSString *)fetchDataListWithModel:(ListRequestModel *)requestModel
                    completion:(InterfaceManagerBlock)completion;



@end

