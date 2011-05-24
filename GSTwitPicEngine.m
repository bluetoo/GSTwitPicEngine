//
//  GSTwitPicEngine.m
//  TwitPic Uploader
//
//  Created by Gurpartap Singh on 19/06/10.
//  Copyright 2010 Gurpartap Singh. All rights reserved.
//

#import "GSTwitPicEngine.h"

#if TWITPIC_USE_YAJL
#import "NSObject+YAJL.h"

#elif TWITPIC_USE_SBJSON
#import "JSON.h"

#elif TWITPIC_USE_TOUCHJSON
#import "CJSONDeserializer.h"

#elif TWITPIC_USE_LIBXML
#include <libxml/xmlreader.h>
#endif

#import "ASIFormDataRequest.h"
#import "ASINetworkQueue.h"

#import "OAConsumer.h"
#import "OARequestHeader.h"

#define kTwitPicUploadUrl @"http://api.twitpic.com/2/upload."TWITPIC_API_FORMAT
#define kYFrogUploadUrl @"http://yfrog.com/api/xauth_upload"

@implementation GSTwitPicEngine

@synthesize _queue;

+ (GSTwitPicEngine *)twitpicEngineWithDelegate:(NSObject *)theDelegate {
  return [[[self alloc] initWithDelegate:theDelegate] autorelease];
}


- (GSTwitPicEngine *)initWithDelegate:(NSObject *)delegate {
  if (self = [super init]) {
    _delegate = delegate;
    _queue = [[ASINetworkQueue alloc] init];
    [_queue setMaxConcurrentOperationCount:1];
    [_queue setShouldCancelAllRequestsOnFailure:NO];
    [_queue setDelegate:self];
    [_queue setRequestDidFinishSelector:@selector(requestFinished:)];
    [_queue setRequestDidFailSelector:@selector(requestFailed:)];
    // [_queue setQueueDidFinishSelector:@selector(queueFinished:)];
  }
  
  return self;
}


- (void)dealloc {
  _delegate = nil;
  [_queue release];
  [super dealloc];
}


#pragma mark -
#pragma mark Instance methods

- (BOOL)_isValidDelegateForSelector:(SEL)selector {
	return ((_delegate != nil) && [_delegate respondsToSelector:selector]);
}


// These methods honor the original intent of this library by assuming TwitPic
- (void)uploadPicture:(UIImage *)image withMessage:(NSString *)message {
    [self uploadPicture:image withMessage:message toUrl:kTwitPicUploadUrl withKey:TWITPIC_API_KEY];
}

- (void)uploadPicture:(UIImage *)picture {
    [self uploadPicture:picture withMessage:@"" toUrl:kTwitPicUploadUrl withKey:TWITPIC_API_KEY];
}

- (void)uploadPictureToTwitPic:(UIImage *)image {
    [self uploadPicture:image];
}

- (void)uploadPictureToYFrog:(UIImage *)image {
    [self uploadPicture:image withMessage:@"" toUrl:kYFrogUploadUrl withKey:nil];
}

- (void)uploadPicture:(UIImage *)picture withMessage:(NSString *)message toUrl:(NSString *)urlString withKey:(NSString *)key {

    NSURL *url = [NSURL URLWithString:urlString];
    
    OAConsumer *consumer = [[[OAConsumer alloc] initWithKey:TWITTER_OAUTH_CONSUMER_KEY secret:TWITTER_OAUTH_CONSUMER_SECRET] autorelease];
    OARequestHeader *requestHeader = [[[OARequestHeader alloc] initWithProvider:@"https://api.twitter.com/1/account/verify_credentials.json"
                                                                         method:@"GET"
                                                                       consumer:consumer
                                                                          token:_accessToken
                                                                          realm:@"http://api.twitter.com/"] autorelease];
    
    NSString *oauthHeaders = [requestHeader generateRequestHeaders];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setUserInfo:[NSDictionary dictionaryWithObject:message forKey:@"message"]];
    
    [request addRequestHeader:@"X-Verify-Credentials-Authorization" value:oauthHeaders];
    [request addRequestHeader:@"X-Auth-Service-Provider" value:@"https://api.twitter.com/1/account/verify_credentials.json"];
    
    if(key) [request addPostValue:key forKey:@"key"];
    [request addPostValue:message forKey:@"message"];
    [request addData:UIImageJPEGRepresentation(picture, 0.8) forKey:@"media"];
    
    request.requestMethod = @"POST";

    [_queue addOperation:request];
    [_queue go];
}


- (void)uploadVideo:(NSData *)videoData {
    [self uploadVideo:videoData withMessage:@""];
}

- (void)uploadVideo:(NSData *)videoData withMessage:(NSString *)message {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://api.twitpic.com/2/upload.%@", TWITPIC_API_FORMAT]];
    
    OAConsumer *consumer = [[[OAConsumer alloc] initWithKey:TWITTER_OAUTH_CONSUMER_KEY secret:TWITTER_OAUTH_CONSUMER_SECRET] autorelease];
    
    // NSLog(@"consumer: %@", consumer);
    
    OARequestHeader *requestHeader = [[[OARequestHeader alloc] initWithProvider:@"https://api.twitter.com/1/account/verify_credentials.json"
                                                                         method:@"GET"
                                                                       consumer:consumer
                                                                          token:_accessToken
                                                                          realm:@"http://api.twitter.com/"] autorelease];
    
    NSString *oauthHeaders = [requestHeader generateRequestHeaders];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setUserInfo:[NSDictionary dictionaryWithObject:message forKey:@"message"]];
    [request setUploadProgressDelegate:self];
    [request setDownloadProgressDelegate:self];
    [request setBytesSentBlock:^(unsigned long long size, unsigned long long total) {
        NSLog(@"Video Bytes sent: %llu total: %llu", size, total);
    }];
    
    [request addRequestHeader:@"X-Verify-Credentials-Authorization" value:oauthHeaders];
    [request addRequestHeader:@"X-Auth-Service-Provider" value:@"https://api.twitter.com/1/account/verify_credentials.json"];
    
    [request addPostValue:TWITPIC_API_KEY forKey:@"key"];
    [request addPostValue:message forKey:@"message"];
    [request addData:videoData forKey:@"media"];
    
    request.requestMethod = @"POST";
    
    [_queue addOperation:request];
    [_queue go];
}

#pragma mark -
#pragma mark OAuth

- (void)setAccessToken:(OAToken *)token {
	[_accessToken autorelease];
	_accessToken = [token retain];
}


#pragma mark -
#pragma mark ASIHTTPRequestDelegate methods

- (void)requestFinished:(ASIHTTPRequest *)request {
  // TODO: Pass values as individual parameters to delegate methods instead of wrapping in NSDictionary.
  NSMutableDictionary *delegateResponse = [[[NSMutableDictionary alloc] init] autorelease];
  
  [delegateResponse setObject:request forKey:@"request"];
  
  NSInteger result = [request responseStatusCode];
  NSLog(@"response %i message: %@", result, [request responseString]);
  switch ([request responseStatusCode]) {
    case 200:
    {
      // Success, but let's parse and see.
      // TODO: Error out if parse failed?
      // TODO: Need further checks for success.
      NSDictionary *response = [[NSDictionary alloc] init];
      NSString *responseString = nil;
      responseString = [request responseString];
      
      @try {
        #if TWITPIC_USE_YAJL
        response = [responseString yajl_JSON];
        #elif TWITPIC_USE_SBJSON
        response = [responseString JSONValue];
        #elif TWITPIC_USE_TOUCHJSON
        NSError *error = nil;

        response = [[CJSONDeserializer deserializer] deserialize:[responseString dataUsingEncoding:NSUTF8StringEncoding] error:&error];
        if (error != nil) {
          @throw([NSException exceptionWithName:@"TOUCHJSONParsingException" reason:[error localizedFailureReason] userInfo:[error userInfo]]);
        }
        // TODO: Implemented XML Parsing.
        // #elif TWITPIC_USE_LIBXML
        #endif
      }
      @catch (NSException *e) {
        NSLog(@"Error while parsing TwitPic response. Does the project really have the parsing library specified? %@.", e);
        return;
      }
      
      [delegateResponse setObject:response forKey:@"parsedResponse"];
      
      if ([self _isValidDelegateForSelector:@selector(twitpicDidFinishUpload:)]) {
        [_delegate twitpicDidFinishUpload:delegateResponse];
      }
      
      break;
    }
    case 400:
      // Failed.
      [delegateResponse setObject:@"Bad request. Missing parameters." forKey:@"errorDescription"];
      
      if ([self _isValidDelegateForSelector:@selector(twitpicDidFailUpload:)]) {
        [_delegate twitpicDidFailUpload:delegateResponse];
      }
      
      break;
    default:
      [delegateResponse setObject:@"Request failed." forKey:@"errorDescription"];
      
      if ([self _isValidDelegateForSelector:@selector(twitpicDidFailUpload:)]) {
        [_delegate twitpicDidFailUpload:delegateResponse];
      }
      
      break;
  }
}


- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSMutableDictionary *delegateResponse = [[[NSMutableDictionary alloc] init] autorelease];
    [delegateResponse setObject:request forKey:@"request"];
    
    NSInteger result = [request responseStatusCode];
    NSLog(@"requestFailed %i message: %@", result, [request responseString]);

    switch ([request responseStatusCode]) {
        case 401:
            // Twitter.com could be down or slow. Or your request took too long to reach twitter.com authentication verification via twitpic.com.
            // TODO: Attempt to try again?
            [delegateResponse setObject:@"Timed out verifying authentication token with Twitter.com. This could be a problem with TwitPic servers. Try again later." forKey:@"errorDescription"];

            break;
        default:
            [delegateResponse setObject:@"Request failed." forKey:@"errorDescription"];
            break;
    }

    if ([self _isValidDelegateForSelector:@selector(twitpicDidFailUpload:)]) {
        [_delegate twitpicDidFailUpload:delegateResponse];
    }
}

#pragma mark -
#pragma mark ASIHTTPRequest Progress Delegates

- (void)request:(ASIHTTPRequest *)request didReceiveBytes:(long long)bytes
{
    NSLog(@"%s: %llu", __FUNCTION__, bytes);
}

- (void)request:(ASIHTTPRequest *)request didSendBytes:(long long)bytes
{
    NSLog(@"%s: %llu", __FUNCTION__, bytes);
}

@end
