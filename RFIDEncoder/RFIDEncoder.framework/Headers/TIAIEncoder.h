//
//  TIAIEncoder.h
//  RFIDEncoder
//
//  Created by Tim.Milne on 2/28/19.
//  Copyright © 2019 Tim Milne. All rights reserved.
//

#import <Foundation/Foundation.h>

// Global values
static NSString *TIAI_A_URI_Prefix   = @"urn:epc:tag:tiai-a-96:0.";
static NSString *TIAI_A_Bin_Prefix   = @"00001010";

@interface TIAIEncoder : NSObject

@property NSString *asset_ref_dec;
@property NSString *asset_ref_bin;
@property NSString *asset_id_dec;
@property NSString *asset_id_char;
@property NSString *asset_id_hex;
@property NSString *asset_id_bin;
@property NSString *tiai_bin;
@property NSString *tiai_hex;
@property NSString *tiai_uri;

- (void)withAssetRef:(NSString *)assetRef
          assetIDDec:(NSString *)assetIDDec;

- (void)withAssetRef:(NSString *)assetRef
         assetIDChar:(NSString *)assetIDChar;

- (void)withAssetRef:(NSString *)assetRef
          assetIDHex:(NSString *)assetIDHex;

// 6 Bit character encoding converters for Asset ID
- (NSString *)Char2Bin:(NSString *)charStr;
- (NSString *)Bin2Char:(NSString *)binStr;

@end
