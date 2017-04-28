//
//  NENetworkingMonitor.m
//  Demo
//
//  Created by sddz_yuxiaohua on 2017/4/26.
//  Copyright © 2017年 XY Co., Ltd. All rights reserved.
//

#import "NENetworkingMonitor.h"

#import "NEURLConnectionProxy.h"

#import <Aspects.h>
#import <objc/runtime.h>

@interface NENetworkingMonitor ()

@property (nonatomic, strong) NSRecursiveLock *lock;

@property (nonatomic, assign) BOOL intercepted;

@property (nonatomic, strong) NSMutableArray *urlConnectionInterceptTokens;

@end

@implementation NENetworkingMonitor

+ (instancetype)defaultMonitor
{
    static NENetworkingMonitor *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [NENetworkingMonitor new];
    });
    
    return instance;
}

+ (void)start
{
    [[NENetworkingMonitor defaultMonitor] startMonitor];
}

+ (void)stop
{
    [[NENetworkingMonitor defaultMonitor] stopMonitor];
}

- (void)startMonitor
{
    [self.lock lock];
    
    if (!self.intercepted) {
        self.intercepted = YES;
        [self startInterceptURLConnection];
    }
    
    [self.lock unlock];
}

- (void)stopMonitor
{
    [self.lock lock];
    
    if (self.intercepted) {
        self.intercepted = NO;
        [self stopInterceptURLConnection];
    }
    
    [self.lock unlock];
}

#pragma mark - private

- (void)startInterceptURLConnection
{
    self.urlConnectionInterceptTokens = [NSMutableArray array];
    
    id token_init =
    [NSURLConnection aspect_hookSelector:@selector(initWithRequest:delegate:)
                             withOptions:AspectPositionBefore
                              usingBlock:
     ^ (id<AspectInfo> instance, NSMutableURLRequest *request, id delegate) {
         if (![request isKindOfClass:[NSMutableURLRequest class]]) {
             request = request.mutableCopy;
         }
         
         NEURLConnectionProxy *proxy = [NEURLConnectionProxy alloc];
         [proxy proxyUsingDelegate:delegate];
         
         [instance.originalInvocation setArgument:&proxy atIndex:3];
         
         NSLog(@"%@", instance.arguments);
     } error:NULL];
    [self.urlConnectionInterceptTokens addObject:token_init];
    
    id token_init2 =
    [NSURLConnection aspect_hookSelector:@selector(initWithRequest:delegate:startImmediately:)
                             withOptions:AspectPositionBefore
                              usingBlock:
     ^ (id<AspectInfo> instance, NSMutableURLRequest *request, id delegate) {
         if (![request isKindOfClass:[NSMutableURLRequest class]]) {
             request = request.mutableCopy;
         }
         
         NEURLConnectionProxy *proxy = [NEURLConnectionProxy alloc];
         [proxy proxyUsingDelegate:delegate];
         [instance.originalInvocation setArgument:&proxy atIndex:3];
         NSLog(@"%@", instance.arguments);
     } error:NULL];
    [self.urlConnectionInterceptTokens addObject:token_init2];
    
    id token_start =
    [NSURLConnection aspect_hookSelector:@selector(start) withOptions:AspectPositionBefore usingBlock:^ (id<AspectInfo> info) {
        NSURLConnection *connection = (NSURLConnection *)info.instance;
        NSURLRequest *request = connection.currentRequest;
        
        if ([NSURLConnection canHandleRequest:connection.currentRequest]) {
            NSLog(@"URL:%@", request.URL);
            NSLog(@"HttpHeaders:%@", request.allHTTPHeaderFields);
            NSLog(@"Body Length:%@", @(request.HTTPBody.length));
        }
    } error:NULL];
    [self.urlConnectionInterceptTokens addObject:token_start];
}

- (void)stopInterceptURLConnection
{
    for (id<AspectToken> token in [self.urlConnectionInterceptTokens copy]) {
        BOOL success = [token remove];
        
        if (!success) {
            NSCAssert(NO, @"");
            
            NSLog(@"Stop Intercept URL Connection Failure with Token: %@", token);
        }
    }
}

@end
