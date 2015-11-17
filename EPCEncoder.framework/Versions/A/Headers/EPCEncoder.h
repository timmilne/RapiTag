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

// Global values
static NSString *SGTIN_URI_Prefix = @"urn:epc:tag:sgtin-96:1.";
static NSString *SGTIN_Bin_Prefix = @"00110000";
static NSString *GID_URI_Prefix   = @"urn:epc:tag:gid-96:";
static NSString *GID_Bin_Prefix   = @"00110101";

@interface EPCEncoder : NSObject

@property NSString *dpt;
@property NSString *cls;
@property NSString *itm;
@property NSString *ser;
@property NSString *gtin;
@property NSString *gid_bin;
@property NSString *gid_hex;
@property NSString *gid_uri;
@property NSString *sgtin_bin;
@property NSString *sgtin_hex;
@property NSString *sgtin_uri;

- (void)withDpt:(NSString *)dpt
        cls:(NSString *)cls
        itm:(NSString *)itm
        ser:(NSString *)ser;

- (void)gidWithGTIN:(NSString *)gtin
            ser:(NSString *)ser;

- (void)withGTIN:(NSString *)gtin
        ser:(NSString *)ser
        partBin:(NSString *)partBin;

- (NSString *)calculateCheckDigit:(NSString *)upc;

@end
