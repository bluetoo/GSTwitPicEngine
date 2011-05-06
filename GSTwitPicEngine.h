//
//  GSTwitPicEngine.h
//  TwitPic Uploader
//
//  Created by Gurpartap Singh on 19/06/10.
//  Copyright 2010 Gurpartap Singh. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "OAToken.h"

#import "ASIHTTPRequest.h"

// Define these API credentials as per your applicationss.

// Get here: http://twitter.com/apps
#define TWITTER_OAUTH_CONSUMER_KEY kTwitterOAuthConsumerKey
#define TWITTER_OAUTH_CONSUMER_SECRET kTwitterOAuthConsumerSecret

// Get here: http://dev.twitpic.com/apps/
#define TWITPIC_API_KEY kTwitPicAPIKey

// TwitPic API Version: http://dev.twitpic.com/docs/
#define TWITPIC_API_VERSION @"2"

// Enable one of the JSON Parsing libraries that the project has.
// Disable all to get raw string as response in delegate call to parse yourself.
#ifndef TWITPIC_USE_YAJL
#define TWITPIC_USE_YAJL 0
#endif

#ifndef TWITPIC_USE_SBJSON
#define TWITPIC_USE_SBJSON 0
#endif

#ifndef TWITPIC_USE_TOUCHJSON
#define TWITPIC_USE_TOUCHJSON 0
#endif

#ifndef TWITPIC_USE_LIBXML
#define TWITPIC_USE_LIBXML 0
#endif

#if TWITPIC_USE_LIBXML
    #define TWITPIC_API_FORMAT @"xml"
#else
    #define TWITPIC_API_FORMAT @"json"
#endif


@protocol GSTwitPicEngineDelegate

- (void)twitpicDidFinishUpload:(NSDictionary *)response;
- (void)twitpicDidFailUpload:(NSDictionary *)error;
- (void)twitpicProgressUpdated:(NSInteger)percentComplete;

@end

@class ASINetworkQueue;

@interface GSTwitPicEngine : NSObject <ASIHTTPRequestDelegate, UIWebViewDelegate> {
  __weak NSObject <GSTwitPicEngineDelegate> *_delegate;
  
	OAToken *_accessToken;
  
  ASINetworkQueue *_queue;
}

@property (retain) ASINetworkQueue *_queue;

+ (GSTwitPicEngine *)twitpicEngineWithDelegate:(NSObject *)theDelegate;
- (GSTwitPicEngine *)initWithDelegate:(NSObject *)theDelegate;

- (void)uploadPicture:(UIImage *)picture;
- (void)uploadPicture:(UIImage *)picture withMessage:(NSString *)message;

- (void)uploadVideo:(NSData *)videoData;
- (void)uploadVideo:(NSData *)videoData withMessage:(NSString *)message;

@end


@interface GSTwitPicEngine (OAuth)

- (void)setAccessToken:(OAToken *)token;

@end
