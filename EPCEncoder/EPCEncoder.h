//
//  EPCEncoder.h
//  EPCEncoder
//
//  Created by Tim.Milne on 4/27/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//
//  This object takes Target's Department, Class, Item and a Serial Number
//  and encodes it in GS1's SGTIN, GIAI, and GID formats.  Output available
//  in binary, hex, and URI formats
//

#import <Foundation/Foundation.h>

@interface EPCEncoder : NSObject

@property NSString *dpt;
@property NSString *cls;
@property NSString *itm;
@property NSString *ser;
@property NSString *sgtin_bin;
@property NSString *sgtin_hex;
@property NSString *sgtin_uri;
@property NSString *giai_bin;
@property NSString *giai_hex;
@property NSString *giai_uri;
@property NSString *gid_bin;
@property NSString *gid_hex;
@property NSString *gid_uri;

- (void)withDpt:(NSString *)Dpt
        cls:(NSString *)Cls
        itm:(NSString *)Itm
        ser:(NSString *)Ser;

- (NSString *)calculateCheckDigit:(NSString *)upc;

@end
