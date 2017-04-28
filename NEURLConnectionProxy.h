//
//  NEURLConnectionProxy.h
//  Demo
//
//  Created by sddz_yuxiaohua on 2017/4/26.
//  Copyright © 2017年 XY Co., Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NEURLConnectionProxy : NSProxy

- (void)proxyUsingDelegate:(id)delegate;

@end
