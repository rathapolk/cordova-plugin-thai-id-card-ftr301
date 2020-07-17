#import "ThaiIdCardCordovaPlugin.h"
#import <Cordova/CDVAvailability.h>
#include "winscard.h"

@implementation ThaiIdCardCordovaPlugin

- (void)pluginInitialize {
    
}

- (void)listReaders:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSLog(@"listReaders - begin");
        
        SCARDCONTEXT context;
        int res = SCardEstablishContext(SCARD_SCOPE_SYSTEM, NULL, NULL, &context);
        if (res != SCARD_S_SUCCESS) {
            NSLog(@"SCardEstablishContext failed: res %d", res);
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }
        
        NSArray *readerList = [self listReadersByContext:context];
        
        SCardReleaseContext(context);
        
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:readerList];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        NSLog(@"listReaders - end");
    }];
}

- (void)readData:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSLog(@"readData - begin");

        NSDictionary *options = [command.arguments objectAtIndex:0];
        NSString *readerName = options[@"readerName"];
        //BOOL readPhoto = [(NSNumber *)options[@"readPhoto"] boolValue];
        
        SCARDCONTEXT context;
        int res = SCardEstablishContext(SCARD_SCOPE_SYSTEM, NULL, NULL, &context);
        if (res != SCARD_S_SUCCESS) {
            NSLog(@"SCardEstablishContext failed: res %d", res);
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }
        
        if (readerName == nil) {
            NSArray *readerList = [self listReadersByContext:context];
            if (readerList.count == 0) {
                SCardReleaseContext(context);
                
                NSLog(@"No reader found!");
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                return;
            }
            readerName = readerList[0];
        }
        
        SCARDHANDLE hCard;
        DWORD activeProtocol;
        res = SCardConnect(context, readerName.UTF8String, SCARD_SHARE_SHARED, SCARD_PROTOCOL_T0, &hCard, &activeProtocol);
        if (res != SCARD_S_SUCCESS) {
            SCardReleaseContext(context);
            
            NSLog(@"SCardConnect failed: res %d", res);
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }
        
        // Select Applet
        if (![self selectApplet:hCard]) {
            SCardReleaseContext(context);
            SCardDisconnect(hCard, SCARD_UNPOWER_CARD);
            
            NSLog(@"SCardTransmit failed: res %d", res);
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }
        
        // read citizen id
        NSString *citizenId = [self readCitizenId: hCard];
        
        
        SCardDisconnect(hCard, SCARD_UNPOWER_CARD);
        
        NSMutableDictionary *message = [[NSMutableDictionary alloc] init];
        message[@"citizenId"] = @"1234567890123";
        message[@"title"] = @"title";
        message[@"firstName"] = @"first";
        message[@"lastName"] = @"last";
        message[@"titleTh"] = @"titleTh";
        message[@"firstNameTh"] = @"firstTh";
        message[@"lastNameTh"] = @"lastTh";
        message[@"birthDate"] = @"1993-04-15";
        message[@"issued"] = @"1993-04-15";
        message[@"expired"] = @"1993-04-15";
        message[@"sex"] = @"m";
        message[@"addressLine"] = @"address";
        message[@"houseNo"] = @"";
        message[@"village"] = @"";
        message[@"lane"] = @"";
        message[@"road"] = @"";
        message[@"subdistrict"] = @"";
        message[@"district"] = @"";
        message[@"province"] = @"";
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        NSLog(@"readData - end");
    }];
}

- (BOOL) selectApplet: (SCARDHANDLE)hCard {
    SCARD_IO_REQUEST     ioRecvPci;
    BYTE selectCommand[] = { 0x00, 0xA4, 0x04, 0x00, 0x08, 0xA0, 0x00, 0x00, 0x00, 0x54, 0x48, 0x00, 0x01 };
    BYTE selectResponse[260];
    DWORD selectResponseLength;
    
    int res = SCardTransmit(hCard, SCARD_PCI_T0,
                  selectCommand, sizeof(selectCommand) , &ioRecvPci,
                  selectResponse, &selectResponseLength);
    if (res != SCARD_S_SUCCESS) {
        NSLog(@"SCardTransmit failed: res %d", res);
        return NO;
    }
    return YES;
}

- (NSString *)readCitizenId: (SCARDHANDLE) hCard {
    SCARD_IO_REQUEST     ioRecvPci;
    BYTE readCidCommand[] = { 0x80, 0xb0, 0x00, 0x04, 0x02, 0x00, 0x0d };
    BYTE readCidResponse[260];
    DWORD readCidResponseLength;
    int res = SCardTransmit(hCard, SCARD_PCI_T0,
                  readCidCommand, sizeof(readCidCommand) , &ioRecvPci,
                  readCidResponse, &readCidResponseLength);
    if (res != SCARD_S_SUCCESS) {
        NSLog(@"SCardTransmit failed: res %d", res);
        return nil;
    }
    
    BYTE getResponseCommand[] = { 0x00, 0xc0, 0x00, 0x00, 0x0d };
    BYTE getResponseResponse[260];
    DWORD getResponseResponseLength;
    
    memset(getResponseResponse, 0, sizeof(getResponseResponse));
    res = SCardTransmit(hCard, SCARD_PCI_T0,
                  getResponseCommand, sizeof(getResponseCommand) , &ioRecvPci,
                  getResponseResponse, &getResponseResponseLength);
    if (res != SCARD_S_SUCCESS) {
        NSLog(@"SCardTransmit failed: res %d", res);
        return nil;
    }
    return [NSString stringWithCString:(const char *)getResponseResponse encoding:NSASCIIStringEncoding];
}

- (NSArray *)listReadersByContext: (SCARDCONTEXT)context {
    DWORD chReaders = 0;
    int res = SCardListReaders(context, NULL, NULL, &chReaders);
    if (res != SCARD_S_SUCCESS) {
        NSLog(@"SCardListReaders failed: res %d", res);
        return [NSMutableArray arrayWithCapacity:0];
    }
    
    LPSTR readers = malloc(sizeof(char)*chReaders);
    res = SCardListReaders(context, NULL, readers, &chReaders);
    if (res != SCARD_S_SUCCESS) {
        NSLog(@"SCardListReaders failed: res %d", res);
        return [NSMutableArray arrayWithCapacity:0];
    }
    NSArray *readerList = [self extractReadersFromString:readers count:chReaders];
    free(readers);
    return readerList;
}

- (NSArray *)extractReadersFromString: (LPSTR)str count:(DWORD)count {
    NSMutableArray *list = [[NSMutableArray alloc]initWithCapacity:1];
    
    int startIndex = 0;
    for (int index = 0; index < count - 1; index++) {
        char ch = *(LPSTR)(str + index);
        if (ch == '\0' && index != startIndex) {
            NSString *name = [NSString stringWithCString:(LPSTR)(str + startIndex) encoding:NSASCIIStringEncoding];
            NSLog(@"Found reader: %@", name);
            [list addObject:name];
            startIndex = index + 1;
        }
    }
    return list;
}

@end
