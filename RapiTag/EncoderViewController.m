//
//  EncoderViewController.m
//  RapiTag
//
//  Created by Tim.Milne on 5/11/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import "EncoderViewController.h"
#import <AVFoundation/AVFoundation.h>   // Barcode capture tools
#import "Ugi.h"                         // uGrokit goodies
#import "EPCEncoder.h"                  // To encode the scanned barcode for comparison
#import "EPCConverter.h"                // To convert to binary for comparison

@interface EncoderViewController ()<AVCaptureMetadataOutputObjectsDelegate, UgiInventoryDelegate>
{
    __weak IBOutlet UILabel         *_dptLbl;
    __weak IBOutlet UILabel         *_clsLbl;
    __weak IBOutlet UILabel         *_itmLbl;
    __weak IBOutlet UILabel         *_serLbl;
    __weak IBOutlet UITextField     *_dptFld;
    __weak IBOutlet UITextField     *_clsFld;
    __weak IBOutlet UITextField     *_itmFld;
    __weak IBOutlet UITextField     *_serFld;
    __weak IBOutlet UIBarButtonItem *_resetBtn;
    __weak IBOutlet UIBarButtonItem *_encodeBtn;
    __weak IBOutlet UIImageView     *_successImg;
    __weak IBOutlet UIImageView     *_failImg;
}
@end

@implementation EncoderViewController {
    EPCEncoder                  *_encode;
    EPCConverter                *_convert;
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
    self.navigationController.navigationBar.BarStyle = UIStatusBarStyleLightContent;
    
    // Initialize variables
    _encode = [EPCEncoder alloc];
    _convert = [EPCConverter alloc];
    _oldEPC = [[NSMutableString alloc] init];
    _newEPC = [[NSMutableString alloc] init];
    _defaultBackgroundColor = UIColorFromRGB(0x000000);
    
    // Set scanner configuration used in startInventory
    _config = [UgiRfidConfiguration configWithInventoryType:UGI_INVENTORY_TYPE_INVENTORY_SHORT_RANGE];
    [_config setVolume:.2];
    
    // TPM: The barcode scanner example built the UI from scratch.  This made it easier to deal with all
    // the setting programatically, so I've continued with that here...
    // Barcode highlight view
    _highlightView = [[UIView alloc] init];
    _highlightView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
    _highlightView.layer.borderColor = [UIColor greenColor].CGColor;
    _highlightView.layer.borderWidth = 3;
    [self.view addSubview:_highlightView];
    
    // Set the labels
    _dptLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _clsLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _itmLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _serLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    
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
    
    // RFID label
    _batteryLifeLbl = [[UILabel alloc] init];
    _batteryLifeLbl.frame = CGRectMake(0, self.view.bounds.size.height - 40, self.view.bounds.size.width, 40);
    _batteryLifeLbl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _batteryLifeLbl.textColor = [UIColor whiteColor];
    _batteryLifeLbl.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_batteryLifeLbl];
    
    // Battery life label
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
    [self.view bringSubviewToFront:_dptLbl];
    [self.view bringSubviewToFront:_clsLbl];
    [self.view bringSubviewToFront:_itmLbl];
    [self.view bringSubviewToFront:_serLbl];
    [self.view bringSubviewToFront:_dptFld];
    [self.view bringSubviewToFront:_clsFld];
    [self.view bringSubviewToFront:_itmFld];
    [self.view bringSubviewToFront:_serFld];
    [self.view bringSubviewToFront:_highlightView];
    [self.view bringSubviewToFront:_barcodeLbl];
    [self.view bringSubviewToFront:_rfidLbl];
    [self.view bringSubviewToFront:_batteryLifeLbl];
    [self.view bringSubviewToFront:_batteryLifeView];
    
    // Reset initializes all the variables and colors
    [self reset:_resetBtn];
    
    // Update the encoder
    [self updateAll];
    
    // Start scanning for barcodes
    [_session startRunning];
}

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
    _serFld.text = @"1234567890";
    
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
    
    // Send the result images to the back
    [self.view sendSubviewToBack:_successImg];
    [self.view sendSubviewToBack:_failImg];
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
            // Tell the uGrokit to beep...
            
            // Grab the barcode
            _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@", detectionString];
            _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
            
            // Now, take the dpt, cls and itm, and encode a reference
            NSString *barcode;
            barcode = detectionString;
            
            if (barcode.length == 13) barcode = [barcode substringFromIndex:1];
            if (barcode.length == 14) barcode = [barcode substringFromIndex:2];
            NSString *mnf = [barcode substringToIndex:2];
            if (barcode.length == 12 && [mnf isEqualToString:@"49"]) {
                NSRange dptRange = {2, 3};
                NSRange clsRange = {5, 2};
                NSRange itmRange = {7, 4};
                NSString *dpt = [barcode substringWithRange:dptRange];
                NSString *cls = [barcode substringWithRange:clsRange];
                NSString *itm = [barcode substringWithRange:itmRange];
                NSString *ser = ([_serFld.text length])?[_serFld text]:@"0";
                
                [_encode withDpt:dpt cls:cls itm:itm ser:ser];
                
                // Set the interface
                [_dptFld setText:dpt];
                [_itmFld setText:itm];
                [_clsFld setText:cls];
            }
            else {
                //Unsupported barcode
                _barcodeLbl.text = @"Barcode: unsupported barcode";
            }
            _barcodeFound = TRUE;
        }
        else
            _barcodeLbl.text = @"Barcode: (scanning for barcodes)";
    }
    
    _highlightView.frame = highlightViewRect;
    
    // If we have a barcode and an RFID tag read, ready to encode
    if (_barcodeFound && _rfidFound) [self readyToEncode];
}

// Delegate to dimiss keyboard after return
// Set the delegate of any input text field to the ViewController class
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

// All the edit fields point here, after you end the edit and hit return
- (IBAction)update:(id)sender {
    [self updateAll];
}

- (void)updateAll {
    NSString *dpt = [_dptFld text];
    NSString *cls = [_clsFld text];
    NSString *itm = [_itmFld text];
    NSString *ser = [_serFld text];
    
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
    
    // Update the EPCEncoder object
    [_encode withDpt:dpt cls:cls itm:itm ser:ser];
    
    if ([dpt length] == 3 && [cls length] == 2 && [itm length] == 4) {
        // Build the barcode
        NSString *barcode = [NSString stringWithFormat:@"49%@%@%@",dpt,cls,itm];
        NSString *chkdgt = [_encode calculateCheckDigit:barcode];
        _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: %@%@", barcode, chkdgt];
        _barcodeLbl.backgroundColor = UIColorFromRGB(0xA4CD39);
    }
    else if ([dpt length] == 0 && [cls length] == 0 && [itm length] == 0) {
        _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (scanning for barcodes)"];
        _barcodeLbl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    }
    else {
        _barcodeLbl.text = [NSString stringWithFormat:@"Barcode: (invalid DPCI)"];
        _barcodeLbl.backgroundColor = UIColorFromRGB(0xCC0000);
    }
    
    // Set the background color
    [self.view setBackgroundColor:_defaultBackgroundColor];
    
    // If we have a barcode and an RFID tag read, ready to encode
    if (_barcodeFound && _rfidFound) [self readyToEncode];
}

- (void)readyToEncode {
    // Enable the encode button
    _encodeBtn.enabled = TRUE;
}

- (IBAction)encodeGID:(id)sender {
    _encoding = TRUE;
    [self beginEncode:[_encode gid_hex]];
}

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
                                          // tag programmed successfully
                                          NSLog(@"Tag programmed successfully");
                                          [self.view setBackgroundColor:UIColorFromRGB(0xA4CD39)];
                                          _rfidLbl.text = [NSString stringWithFormat:@"RFID: %@", _newEPC];
                                          [self.view bringSubviewToFront:_successImg];
                                          _successImg.hidden = FALSE;
                                          
                                      } else {
                                          // tag programming was unsuccessful
                                          NSLog(@"Tag programming UNSUCCESSFUL");
                                          [self.view setBackgroundColor:UIColorFromRGB(0xCC0000)];
                                          [self.view bringSubviewToFront:_failImg];
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

// Implemented uGrokit delegates

// New tag found
- (void) inventoryTagFound:(UgiTag *)tag
   withDetailedPerReadData:(NSArray *)detailedPerReadData {
    // Tag was found for the first time
    
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
        // If we have a barcode and an RFID tag read, ready to encode
        if (_barcodeFound && _rfidFound) [self readyToEncode];
        _rfidFound = TRUE;
    }
}

// State changed method
- (void)connectionStateChanged:(NSNotification *) notification {
    // Listen for one of the following:
    //    UGI_CONNECTION_STATE_NOT_CONNECTED,        //!< Nothing connected to audio port
    //    UGI_CONNECTION_STATE_CONNECTING,           //!< Something connected to audio port, trying to connect
    //    UGI_CONNECTION_STATE_INCOMPATIBLE_READER,  //!< Connected to an reader with incompatible firmware
    //    UGI_CONNECTION_STATE_CONNECTED             //!< Connected to reader
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
