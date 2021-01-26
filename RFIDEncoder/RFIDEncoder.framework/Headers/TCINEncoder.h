//
//  TCINEncoder.h
//  RFIDEncoder
//
//  Created by Tim.Milne on 2/28/19.
//  Copyright © 2019 Tim Milne. All rights reserved.
//
//  This object takes a Target Common Item Number (TCIN) and encodes it in a proprietary
//  TCIN-96 format.  Output available in binary, hex and URI formats.  If no unique serial
//  number is available, there are two initializers that will leverage a linear congruential
//  generator to create a pseudo random serial number, one with a seed, one without.
//

#import <Foundation/Foundation.h>

// Global values
static NSString *TCIN_URI_Prefix   = @"urn:epc:tag:tcin-96:0.";
static NSString *TCIN_Bin_Prefix   = @"00001000";

@interface TCINEncoder : NSObject

@property NSString *tcin;
@property NSString *ser;
@property NSString *tcin_bin;
@property NSString *tcin_hex;
@property NSString *tcin_uri;

// Generate a random serial number
- (void)withTCIN:(NSString *)tcin;

// Generate a random serial number with a seed, up to 13 digits
- (void)withTCIN:(NSString *)tcin
             seed:(long long)seed;

// Use the specified serial number
- (void)withTCIN:(NSString *)tcin
             ser:(NSString *)ser;

@end
