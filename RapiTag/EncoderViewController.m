//
//  EncoderViewController.m
//  RapiTag
//
//  Created by Tim.Milne on 5/11/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import "EncoderViewController.h"
#import <AVFoundation/AVFoundation.h> // Barcode capture tools
#import "Ugi.h"                       // uGrokit goodies
#import "EPCEncoder.h"                // To encode the scanned barcode for comparison
#import "Converter.h"                 // To convert to binary for comparison

@interface EncoderViewController ()<AVCaptureMetadataOutputObjectsDelegate, UgiInventoryDelegate>
{
    __weak IBOutlet UILabel         *_dptLbl;
    __weak IBOutlet UILabel         *_clsLbl;
    __weak IBOutlet UILabel         *_itmLbl;
    __weak IBOutlet UILabel         *_serLbl;
    __weak IBOutlet UILabel         *_gtinLbl;
    __weak IBOutlet UITextField     *_dptFld;
    __weak IBOutlet UITextField     *_clsFld;
    __weak IBOutlet UITextField     *_itmFld;
    __weak IBOutlet UITextField     *_serFld;
    __weak IBOutlet UITextField     *_gtinFld;
    __weak IBOutlet UIBarButtonItem *_resetBtn;
    __weak IBOutlet UIBarButtonItem *_encodeBtn;
    __weak IBOutlet UIImageView     *_successImg;
    __weak IBOutlet UIImageView     *_failImg;
}
@end

@implementation EncoderViewController {
    EPCEncoder                  *_encode;
    Converter                   *_convert;
    UgiRfidConfiguration        *_config;
    NSMutableString             *_oldEPC;
    NSMutableString             *_newEPC;
    UIColor                     *_defaultBackgroundColor;
    
    UIView                      *_highlightView;
    UILabel                     *_barcodeLbl;
    UILabel                     *_rfidLbl;
    UILabel                     *_batteryLifeLbl;
    UIProgressView              *_batteryLifeView;
    
    AVCaptureSession            *_session;
    AVCaptureDevice             *_device;
    AVCaptureDeviceInput        *_input;
    AVCaptureMetadataOutput     *_output;
    AVCaptureVideoPreviewLayer  *_prevLayer;
    
    BOOL                        _barcodeFound;
    BOOL                        _rfidFound;
    BOOL                        _encoding;
}

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:0.65]

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Set the status bar to white (iOS bug)
    // Also had to add the statusBarStyle entry to info.plist
    self.navigationController.navigationBar.barStyle = UIStatusBarStyleLightContent;
    
    // Initialize variables
    _encode = [EPCEncoder alloc];
    _convert = [Converter alloc];
    _oldEPC = [[NSMutableString alloc] init];
    _newEPC = [[NSMutableString alloc] init];
    _defaultBackgroundColor = UIColorFromRGB(0x000000);
    
    // Set scanner configuration used in startInventory
    _config = [UgiRfidConfiguration configWithInventoryType:UGI_INVENTORY_TYPE_INVENTORY_SHORT_RANGE];
    [_config setVolume:.2];
    
    // Set the label background colors
    _dptLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _clsLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _itmLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _serLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _gtinLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    
    // TPM: The barcode scanner example built the UI from scratch.  This made it easier to deal with all
    // the settings programatically, so I've continued with that here...
    // Barcode highlight view
    _highlightView = [[UIView alloc] init];
    _highlightView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
    _highlightView.layer.borderColor = [UIColor greenColor].CGColor;
    _highlightView.layer.borderWidth = 3;
    [self.view addSubview:_highlightView];
    
    // Barcode label view
    _barcodeLbl = [[UILabel alloc] init];
    _barcodeLbl.frame = CGRectMake(0, self.view.bounds.size.height - 120, self.view.bounds.size.width, 40);
    _barcodeLbl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _barcodeLbl.textColor = [UIColor whiteColor];
    _barcodeLbl.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_barcodeLbl];
    
    // RFID label view
    _rfidLbl = [[UILabel alloc] init];
    _rfidLbl.frame = CGRectMake(0, self.view.bounds.size.height - 80, self.view.bounds.size.width, 40);
    _rfidLbl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _rfidLbl.textColor = [UIColor whiteColor];
    _rfidLbl.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_rfidLbl];
    
    // Battery life label
    _batteryLifeLbl = [[UILabel alloc] init];
    _batteryLifeLbl.frame = CGRectMake(0, self.view.bounds.size.height - 40, self.view.bounds.size.width, 40);
    _batteryLifeLbl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _batteryLifeLbl.textColor = [UIColor whiteColor];
    _batteryLifeLbl.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_batteryLifeLbl];
    
    // Battery life view
    _batteryLifeView = [[UIProgressView alloc] init];
    _batteryLifeView.frame = CGRectMake(0, self.view.bounds.size.height - 8, self.view.bounds.size.width, 40);
    _batteryLifeView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:_batteryLifeView];
    
    // Initialize the bar code scanner session, device, input, output, and preview layer
    _session = [[AVCaptureSession alloc] init];
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:&error];
    if (_input) {
        [_session addInput:_input];
    } else {
        NSLog(@"Error: %@", error);
    }
    _output = [[AVCaptureMetadataOutput alloc] init];
    [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [_session addOutput:_output];
    _output.metadataObjectTypes = [_output availableMetadataObjectTypes];
    _prevLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _prevLayer.frame = self.view.bounds;
    _prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:_prevLayer];
    
    // Register with the default NotificationCenter for RFID reads
    // TPM there was a typo in the online documentation fixed here
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionStateChanged:)
                                                 name:[Ugi singleton].NOTIFICAION_NAME_CONNECTION_STATE_CHANGED
                                               object:nil];
    
    // Pop the subviews to the front of the preview view
    [self.view bringSubviewToFront:_highlightView];
    [self.view bringSubviewToFront:_barcodeLbl];
    [self.view bringSubviewToFront:_rfidLbl];
    [self.view bringSubviewToFront:_batteryLifeLbl];
    [self.view bringSubviewToFront:_batteryLifeView];
    [self.view bringSubviewToFront:_successImg];
    [self.view bringSubviewToFront:_failImg];
    
    // Reset initializes all the variables and colors and pops the remaining views
    [self reset:_resetBtn];
    
    // Update the encoder
    [self updateAll];
    
    // Start scanning for barcodes
    [_session startRunning];
}

/*!
 * @discussion Adjust the preview layer on orientation changes
 */
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    switch ((int)orientation) {
        case UIInterfaceOrientationPortrait:
            [_prevLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            [_prevLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
            break;
        case UIInterfaceOrientationLandscapeLeft:
            [_prevLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
            break;
        case UIInterfaceOrientationLandscapeRight:
            [_prevLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
            break;
    }
}

/*!
 * @discussion Press reset button to reset the interface and reader and begin reading.
 * @param sender An id for the sender control
 */
- (IBAction)reset:(id)sender {
    // Reset all controls and variables
    _barcodeFound = FALSE;
    _rfidFound = FALSE;
    _encodeBtn.enabled = FALSE;
    _encoding = FALSE;
    [_oldEPC setString:@""];
    [_newEPC setString:@""];
    [self.view setBackgroundColor:_defaultBackgroundColor];
    
    _dptFld.text = @"";
    _clsFld.text = @"";
    _itmFld.text = @"";
    _serFld.text = @"1";
    _gtinFld.text = @"";
    
    _barcodeLbl.text = @"Barcode: (scanning for barcodes)";
    _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _rfidLbl.text = @"RFID: (connecting to reader)";
    _rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    
    // Update the battery life
    UgiBatteryInfo batteryInfo;
    if ([[Ugi singleton] getBatteryInfo:&batteryInfo]) {
        _batteryLifeView.progress = (batteryInfo.percentRemaining)/100.;
        _batteryLifeLbl.backgroundColor =
        (batteryInfo.percentRemaining > 20)?UIColorFromRGB(0xA4CD39):
        (batteryInfo.percentRemaining > 5 )?UIColorFromRGB(0xCC9900):
        UIColorFromRGB(0xCC0000);
        _batteryLifeLbl.text = [NSString stringWithFormat:@"RFID Battery Life: %d%%", batteryInfo.percentRemaining];
    }
    else {
        _batteryLifeView.progress = 0.;
        _batteryLifeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
        _batteryLifeLbl.text = @"RFID Battery Life";
    }
    
    // Bring the input views to the front
    [self.view bringSubviewToFront:_dptLbl];
    [self.view bringSubviewToFront:_clsLbl];
    [self.view bringSubviewToFront:_itmLbl];
    [self.view bringSubviewToFront:_serLbl];
    [self.view bringSubviewToFront:_gtinLbl];
    [self.view bringSubviewToFront:_dptFld];
    [self.view bringSubviewToFront:_clsFld];
    [self.view bringSubviewToFront:_itmFld];
    [self.view bringSubviewToFront:_serFld];
    [self.view bringSubviewToFront:_gtinFld];
    
    // Hide the result images (treat these different for landscape mode)
    _successImg.hidden = TRUE;
    _failImg.hidden = TRUE;
    
    // Stop inventory if active
    [[Ugi singleton].activeInventory stopInventory];
    [[Ugi singleton] closeConnection];
    [[Ugi singleton] openConnection];  // Does a lot of things, including check battery life, and start an inventory
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Barcode scanner
#pragma mark - Barcode Scanner Delegates

/*!
 * @discussion Check for a valid scanned barcode, only proceed if a valid barcode found.  Check for ready to encode.
 */
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    CGRect highlightViewRect = CGRectZero;
    AVMetadataMachineReadableCodeObject *barCodeObject;
    NSString *detectionString = nil;
    NSArray *barCodeTypes = @[AVMetadataObjectTypeUPCECode, AVMetadataObjectTypeCode39Code, AVMetadataObjectTypeCode39Mod43Code,
                              AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode93Code, AVMetadataObjectTypeCode128Code,
                              AVMetadataObjectTypePDF417Code, AVMetadataObjectTypeQRCode, AVMetadataObjectTypeAztecCode];
    
    for (AVMetadataObject *metadata in metadataObjects) {
        for (NSString *type in barCodeTypes) {
            if ([metadata.type isEqualToString:type])
            {
                barCodeObject = (AVMetadataMachineReadableCodeObject *)[_prevLayer transformedMetadataObjectForMetadataObject:(AVMetadataMachineReadableCodeObject *)metadata];
                highlightViewRect = barCodeObject.bounds;
                detectionString = [(AVMetadataMachineReadableCodeObject *)metadata stringValue];
                break;
            }
        }
        
        if (detectionString != nil)
        {
            // Assume false until verified
            _barcodeFound = FALSE;
            
            // New input data
            _successImg.hidden = TRUE;
            _failImg.hidden = TRUE;
            
            // Grab the barcode
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", detectionString];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
            NSString *barcode;
            barcode = detectionString;
            
            // Quick length checks, chop to 12 for now (remove leading zeros)
            if (barcode.length == 13) barcode = [barcode substringFromIndex:1];
            if (barcode.length == 14) barcode = [barcode substringFromIndex:2];
            
            // Owned brand, encode DPCI in a GID
            if (barcode.length == 12 && [[barcode substringToIndex:2] isEqualToString:@"49"]) {
                NSString *dpt = [barcode substringWithRange:NSMakeRange(2,3)];
                NSString *cls = [barcode substringWithRange:NSMakeRange(5,2)];
                NSString *itm = [barcode substringWithRange:NSMakeRange(7,4)];
                NSString *ser = ([_serFld.text length])?[_serFld text]:@"0";
                
                [_encode withDpt:dpt cls:cls itm:itm ser:ser];
                
                // Set the interface
                [_dptFld setText:dpt];
                [_itmFld setText:itm];
                [_clsFld setText:cls];
                [_gtinFld setText:@""];
                
                // Show DPCI
                [self.view bringSubviewToFront:_dptLbl];
                [self.view bringSubviewToFront:_clsLbl];
                [self.view bringSubviewToFront:_itmLbl];
                [self.view bringSubviewToFront:_dptFld];
                [self.view bringSubviewToFront:_clsFld];
                [self.view bringSubviewToFront:_itmFld];
                
                // Hide GTIN
                [self.view sendSubviewToBack:_gtinLbl];
                [self.view sendSubviewToBack:_gtinFld];
                
                _barcodeFound = TRUE;
            }
            
            // National brand, encode GTIN in an SGTIN
            else if ((barcode.length == 12) || (barcode.length == 14)) {
                // Take the gtin and encode a reference
                NSString *gtin = barcode;
                NSString *ser  = ([_serFld.text length])?[_serFld text]:@"0";
                
                [_encode withGTIN:gtin ser:ser partBin:@"101"];
                
                // Set the interface
                [_gtinFld setText:barcode];
                [_dptFld setText:@""];
                [_clsFld setText:@""];
                [_itmFld setText:@""];
                
                // Show GTIN
                [self.view bringSubviewToFront:_gtinLbl];
                [self.view bringSubviewToFront:_gtinFld];
                
                // Hide DPCI
                [self.view sendSubviewToBack:_dptLbl];
                [self.view sendSubviewToBack:_clsLbl];
                [self.view sendSubviewToBack:_itmLbl];
                [self.view sendSubviewToBack:_dptFld];
                [self.view sendSubviewToBack:_clsFld];
                [self.view sendSubviewToBack:_itmFld];
                
                _barcodeFound = TRUE;
            }
            
            // Unsupported barcode
            else {
                
                _barcodeLbl.text = @"Barcode: unsupported barcode";
                _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
                _barcodeFound = FALSE;
            }
        }
        
        // Still scanning for barcodes
        else {
            _barcodeLbl.text = @"Barcode: (scanning for barcodes)";
            _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
            _barcodeFound = FALSE;
        }
    }
    
    _highlightView.frame = highlightViewRect;
    
    // Check to see if ready to encode
    [self readyToEncode];
}

// Text field delegates
#pragma mark - Text Fields

/*!
 * @discussion Delegate to dimiss keyboard after return.
 * Set the delegate of any input text field to the ViewController class
 */
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

/*!
 * @discussion Update the interface - All the edit fields point here, after you end the edit and hit return.
 */
- (IBAction)update:(id)sender {
    // New input data
    _successImg.hidden = TRUE;
    _failImg.hidden = TRUE;
    
    [self updateAll];
}

/*!
 * @discussion Update all elements for any input change.  Check input and check ready to encode.
 */
- (void)updateAll {
    NSString *dpt  = [_dptFld text];
    NSString *cls  = [_clsFld text];
    NSString *itm  = [_itmFld text];
    NSString *ser  = [_serFld text];
    NSString *gtin = [_gtinFld text];
    
    // Make sure the inputs are not too long (especially the Serial Number)
    if ([dpt length] > 3) {
        dpt = [dpt substringToIndex:3];
        [_dptFld setText:dpt];
    }
    if ([cls length] > 2) {
        cls = [cls substringToIndex:2];
        [_clsFld setText:cls];
    }
    if ([itm length] > 4) {
        itm = [itm substringToIndex:4];
        [_itmFld setText:itm];
    }
    if ([ser length] > 10) {
        // GID serial number max = 10
        ser = [ser substringToIndex:10];
        [_serFld setText:ser];
    }
    if ([ser length] > 10) {
        // GID serial number max = 10
        ser = [ser substringToIndex:10];
        [_serFld setText:ser];
    }
    if ([gtin length] > 14) {
        gtin = [gtin substringToIndex:14];
        [_gtinFld setText:gtin];
    }
    
    if ([dpt length] > 0 && [cls length] > 0 && [itm length] > 0 && [ser length] > 0) {
        // Update the EPCEncoder object
        [_encode withDpt:dpt cls:cls itm:itm ser:ser];
        
        if ([dpt length] == 3 && [cls length] == 2 && [itm length] == 4) {
            // Build the barcode
            NSString *barcode = [NSString stringWithFormat:@"49%@%@%@",dpt,cls,itm];
            NSString *chkdgt = [_encode calculateCheckDigit:barcode];
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@%@", barcode, chkdgt];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
            _barcodeFound = TRUE;
            
            // Hide GTIN
            [self.view sendSubviewToBack:_gtinLbl];
            [self.view sendSubviewToBack:_gtinFld];
        }
        else {
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (invalid DPCI)"];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
            _barcodeFound = FALSE;
        }
    }
    else if ([ser length] > 0 && [gtin length] > 0) {
        // Update the EPCEncoder object
        [_encode withGTIN:gtin ser:ser partBin:@"101"];
        
        if ([gtin length] == 14 || [gtin length] == 12) {
            _barcodeLbl.text = gtin;
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
            _barcodeFound = TRUE;
            
            // Hide DPCI
            [self.view sendSubviewToBack:_dptLbl];
            [self.view sendSubviewToBack:_clsLbl];
            [self.view sendSubviewToBack:_itmLbl];
            [self.view sendSubviewToBack:_dptFld];
            [self.view sendSubviewToBack:_clsFld];
            [self.view sendSubviewToBack:_itmFld];
        }
        else {
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (invalid GTIN)"];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
            _barcodeFound = FALSE;
        }
    }
    else {
        _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (scanning for barcodes)"];
        _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
        _barcodeFound = FALSE;
    }
    
    // Set the background color
    [self.view setBackgroundColor:_defaultBackgroundColor];
    
    // Check to see if ready to encode
    [self readyToEncode];
}

// Encode
#pragma mark - Encode

/*!
 * @discussion Check for ready to encode - Enable the encode button if all input ready.
 */
- (void)readyToEncode {
    // If we have a valid barcode and an RFID tag read, we are ready to encode so enable the encode button
    _encodeBtn.enabled = (_barcodeFound && _rfidFound);
}

/*!
 * @discussion Encode handler - Prepare to encode.
 * @param sender The ID of the sender object (not used)
 */
- (IBAction)encode:(id)sender {
    _encoding = TRUE;
    
    // New encoding attempt
    _successImg.hidden = TRUE;
    _failImg.hidden = TRUE;

    NSString *ser  = [_serFld text];
    NSString *gtin = [_gtinFld text];
    
    [self beginEncode:([ser length] > 0 && [gtin length] > 0)?[_encode sgtin_hex]:[_encode gid_hex]];
}

/*!
 * @discussion Begin the encoding process.
 * @param hex The new tag number to encode (hex)
 */
- (void)beginEncode:(NSString *)hex {
    [_newEPC setString:hex];
    
    if ([_oldEPC length] == 0) {
        // No reader, no encoding
        if (![[Ugi singleton] isAnythingPluggedIntoAudioJack]) return;
        if (![[Ugi singleton] inOpenConnection]) return;
        
        // Start scanning for RFID tags - when a tag is found, the inventoryTagFound delegate will be called
        [[Ugi singleton] startInventory:self withConfiguration:_config];
    }
    else {
        [self endEncode:_oldEPC];
    }
}

/*!
 * @discussion End the encoding process.
 * @param hex The Old EPC (will be replaced)
 */
-(void)endEncode:(NSString *)hex {
    [_oldEPC setString:hex];
    
    if ([_newEPC length] == 0) return;
    
    // Set the programming inputs
    UgiEpc *oldEpc = [UgiEpc epcFromString:_oldEPC];
    UgiEpc *newEpc = [UgiEpc epcFromString:_newEPC];
    
    // Encode it with the new number
    [[Ugi singleton].activeInventory programTag:oldEpc
                                          toEpc:newEpc
                                   withPassword:UGI_NO_PASSWORD
                                  whenCompleted:^(UgiTag *tag, UgiTagAccessReturnValues result) {
                                      if (result == UGI_TAG_ACCESS_OK) {
                                          // Tag programmed successfully
                                          NSLog(@"Tag programmed successfully");
                                          [self.view setBackgroundColor:UIColorFromRGB(0xA4CD39)];
                                          _rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", _newEPC];
                                          
                                          // Increment the serial number for another run and update
                                          NSInteger serInt = [[_serFld text] intValue];
                                          [_serFld setText:[NSString stringWithFormat:@"%d", (++serInt)]];
                                          [self updateAll];
                                          _successImg.hidden = FALSE;
                                      }
                                      else {
                                          // Tag programming was unsuccessful
                                          NSLog(@"Tag programming UNSUCCESSFUL");
                                          [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
                                          _failImg.hidden = FALSE;
                                          
                                      }
                                      // Stop the RFID reader
                                      [[Ugi singleton].activeInventory stopInventory];
                                      
                                      // Update the battery life
                                      UgiBatteryInfo batteryInfo;
                                      if ([[Ugi singleton] getBatteryInfo:&batteryInfo]) {
                                          _batteryLifeView.progress = (batteryInfo.percentRemaining)/100.;
                                          _batteryLifeLbl.backgroundColor =
                                            (batteryInfo.percentRemaining > 20)?UIColorFromRGB(0xA4CD39):
                                            (batteryInfo.percentRemaining > 5 )?UIColorFromRGB(0xCC9900):
                                                                                UIColorFromRGB(0xCC0000);
                                          _batteryLifeLbl.text = [NSString stringWithFormat:@"RFID Battery Life: %d%%", batteryInfo.percentRemaining];
                                      }
                                  }];
    
    // Our work is done
    [_oldEPC setString:@""];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
 */

// uGrokit RFID Reader
#pragma mark - uGrokit Delegates

/*!
 * @discussion New tag found with uGrokit reader.
 * Display the tag, stop the reader and check if ready to encode.
 * @param tag The RFID tag
 * @param detailedPerReadData The detailed data about the RFID tag
 */
- (void) inventoryTagFound:(UgiTag *)tag
   withDetailedPerReadData:(NSArray *)detailedPerReadData {
    // Tag was found for the first time
    
    // New input data
    _successImg.hidden = TRUE;
    _failImg.hidden = TRUE;
    
    // Set the old EPC
    [_oldEPC setString:[tag.epc toString]];

    // Get the RFID tag
    _rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", [tag.epc toString]];
    _rfidLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
    
    if (_encoding) {
        [self endEncode:_oldEPC];
        _encoding = FALSE;
    }
    else {
        _rfidFound = TRUE;
        
        // Check to see if ready to encode
        [self readyToEncode];
    }
}

/*!
 * @discussion State changed with uGrokit reader - Adjust to the new state.
 * Listen for one of the following:
 *    UGI_CONNECTION_STATE_NOT_CONNECTED -          Nothing connected to audio port
 *    UGI_CONNECTION_STATE_CONNECTING -             Something connected to audio port, trying to connect
 *    UGI_CONNECTION_STATE_INCOMPATIBLE_READER -    Connected to an reader with incompatible firmware
 *    UGI_CONNECTION_STATE_CONNECTED -              Connected to reader
 * @param notification The notification info
 */
- (void)connectionStateChanged:(NSNotification *) notification {
    NSNumber *n = notification.object;
    UgiConnectionStates connectionState = n.intValue;
    if (connectionState == UGI_CONNECTION_STATE_CONNECTED) {
        // Update the battery life with a new connection before starting an inventory
        UgiBatteryInfo batteryInfo;
        if ([[Ugi singleton] getBatteryInfo:&batteryInfo]) {
            _batteryLifeView.progress = (batteryInfo.percentRemaining)/100.;
            _batteryLifeLbl.backgroundColor =
            (batteryInfo.percentRemaining > 20)?UIColorFromRGB(0xA4CD39):
            (batteryInfo.percentRemaining > 5 )?UIColorFromRGB(0xCC9900):
                                                UIColorFromRGB(0xCC0000);
            
            _batteryLifeLbl.text = [NSString stringWithFormat:@"RFID Battery Life: %d%%", batteryInfo.percentRemaining];
        }
        
        // Start scanning for RFID tags - when a tag is found, the inventoryTagFound delegate will be called
        _rfidLbl.text = @"RFID: (scanning for tags)";
        [[Ugi singleton] startInventory:self withConfiguration:_config];
        return;
    }
    if (connectionState == UGI_CONNECTION_STATE_CONNECTING) {
        _rfidLbl.text = @"RFID: (connecting to reader)";
        _rfidLbl.backgroundColor = UIColorFromRGB(0xCC9900);
        return;
    }
    if (connectionState == UGI_CONNECTION_STATE_INCOMPATIBLE_READER) {
        // With no reader, just ignore the RFID reads
        _rfidLbl.text = @"RFID: (no compatible reader)";
        _rfidLbl.backgroundColor = UIColorFromRGB(0xCC0000);
        _batteryLifeView.progress = 0.;
        _batteryLifeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
        _batteryLifeLbl.text = @"RFID Battery Life";
        _rfidFound = FALSE;
        return;
    }
    if (connectionState == UGI_CONNECTION_STATE_NOT_CONNECTED ) {
        // Reader not connected, just ignore the RFID reads
        _rfidLbl.text = @"RFID: (reader not connected)";
        _rfidLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
        _batteryLifeView.progress = 0.;
        _batteryLifeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
        _batteryLifeLbl.text = @"RFID Battery Life";
        _rfidFound = FALSE;
        return;
    }
}

@end
