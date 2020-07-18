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
        
        BOOL readCitizenId = options[@"readCitizenId"] == nil? YES : [(NSNumber *)options[@"readCitizenId"] boolValue];
        BOOL readPersonal = options[@"readPersonal"] == nil? YES : [(NSNumber *)options[@"readPersonal"] boolValue];
        BOOL readAddress = options[@"readAddress"] == nil? YES : [(NSNumber *)options[@"readAddress"] boolValue];
        BOOL readIssuedExpired = options[@"readIssuedExpired"] == nil? YES : [(NSNumber *)options[@"readIssuedExpired"] boolValue];
        BOOL readPhoto = [(NSNumber *)options[@"readPhoto"] boolValue];
        
        SCARDCONTEXT context;
        int res = SCardEstablishContext(SCARD_SCOPE_SYSTEM, NULL, NULL, &context);
        if (res != SCARD_S_SUCCESS) {
            NSString *errorMessage = [NSString stringWithFormat:@"SCardEstablishContext failed: res %X", res];
            NSLog(@"%@", errorMessage);
            
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }
        
        if (readerName == nil) {
            NSArray *readerList = [self listReadersByContext:context];
            if (readerList.count == 0) {
                SCardReleaseContext(context);
                
                NSString * errorMessage = @"No reader found!";
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
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
            NSString *errorMessage = @"Card not present.";
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }
        
        // Select Applet
        if (![self selectApplet:hCard]) {
            SCardDisconnect(hCard, SCARD_UNPOWER_CARD);
            SCardReleaseContext(context);
            
            NSLog(@"SCardTransmit failed: res %X", res);
            NSString *errorMessage = @"This card may not be Thai id.";
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }
        
        // read citizen id
        NSString *citizenId = nil;
        if (readCitizenId) {
            citizenId = [self readCitizenId:hCard];
            if (citizenId == nil) {
                SCardDisconnect(hCard, SCARD_UNPOWER_CARD);
                SCardReleaseContext(context);
                
                NSString *errorMessage = @"Reading citizen id failed.";
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                return;
            }
        }
        
        // read personal info
        NSString *titleTh = nil;
        NSString *firstNameTh = nil;
        NSString *middleNameTh = nil;
        NSString *lastNameTh = nil;
        NSString *titleEn = nil;
        NSString *firstNameEn = nil;
        NSString *middleNameEn = nil;
        NSString *lastNameEn = nil;
        NSString *formattedBirthDate = nil;
        NSString *sex;
        
        if (readPersonal) {
            NSString *personalInfo = [self readPersonalInfo:hCard];
            if (personalInfo == nil) {
                SCardDisconnect(hCard, SCARD_UNPOWER_CARD);
                SCardReleaseContext(context);
                
                NSString *errorMessage = @"Reading personal info failed.";
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                return;
            }
            
            NSString *personalInfoTh = [personalInfo substringWithRange:NSMakeRange(0, 100)];
            NSString *personalInfoEn = [personalInfo substringWithRange:NSMakeRange(100, 100)];
            
            sex = [personalInfo substringWithRange:NSMakeRange(208, 1)];
            NSArray *thaiComponentsArray = [personalInfoTh componentsSeparatedByString: @"#"];
            if (thaiComponentsArray.count >= 4) {
                titleTh = thaiComponentsArray[0];
                firstNameTh = thaiComponentsArray[1];
                middleNameTh = thaiComponentsArray[2];
                lastNameTh = thaiComponentsArray[3];
            }
            
            NSArray *englishComponentsArray = [personalInfoEn componentsSeparatedByString: @"#"];
            if (englishComponentsArray.count >= 4) {
                titleEn = englishComponentsArray[0];
                firstNameEn = englishComponentsArray[1];
                middleNameEn = englishComponentsArray[2];
                lastNameEn = englishComponentsArray[3];
            }
            
            NSString *birthDateString = [personalInfo substringWithRange:NSMakeRange(200, 8)];
            formattedBirthDate = [self formatDateFromIdCard:birthDateString];
        }
        
        // read address
        NSString *addressLine = nil;
        NSString *houseNo = nil;
        NSString *village = nil;
        NSString *lane = nil;
        NSString *road = nil;
        NSString *subdistrict = nil;
        NSString *district = nil;
        NSString *province = nil;
        
        if (readAddress) {
            NSString *address = [self readAddress:hCard];
            if (address == nil) {
                SCardDisconnect(hCard, SCARD_UNPOWER_CARD);
                SCardReleaseContext(context);
                
                NSString *errorMessage = @"Reading address failed.";
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                return;
            }
            
            NSArray *addressComponents = [address componentsSeparatedByString:@"#"];
            if (addressComponents.count >= 8) {
                houseNo = addressComponents[0];
                village = addressComponents[1];
                lane = addressComponents[2];
                road = addressComponents[3];
                subdistrict = addressComponents[5];
                district = addressComponents[6];
                province = addressComponents[7];
                
                addressLine = [addressComponents componentsJoinedByString:@" "];
            }
        }
        
        NSString *formattedIssuedDate = nil;
        NSString *formattedExpiredDate = nil;
        if (readIssuedExpired) {
            NSString *issuedExpired = [self readIssuedExpired:hCard];
            NSString *issuedString = [issuedExpired substringWithRange:NSMakeRange(0, 8)];
            NSString *expiredString = [issuedExpired substringWithRange:NSMakeRange(8, 8)];
            formattedIssuedDate = [self formatDateFromIdCard:issuedString];
            formattedExpiredDate = [self formatDateFromIdCard:expiredString];
        }
        
        SCardDisconnect(hCard, SCARD_UNPOWER_CARD);
        SCardReleaseContext(context);
        
        NSMutableDictionary *message = [[NSMutableDictionary alloc] init];
        message[@"citizenId"] = citizenId;
        message[@"titleTh"] = titleTh;
        message[@"firstNameTh"] = firstNameTh;
        message[@"middleNameTh"] = middleNameTh;
        message[@"lastNameTh"] = lastNameTh;
        message[@"titleEn"] = titleEn;
        message[@"firstNameEn"] = firstNameEn;
        message[@"middleNameEn"] = middleNameEn;
        message[@"lastNameEn"] = lastNameEn;
        message[@"birthDate"] = formattedBirthDate;
        message[@"sex"] = sex;
        message[@"issued"] = formattedIssuedDate;
        message[@"expired"] = formattedExpiredDate;
        message[@"addressLine"] = addressLine;
        message[@"houseNo"] = houseNo;
        message[@"village"] = village;
        message[@"lane"] = lane;
        message[@"road"] = road;
        message[@"subdistrict"] = subdistrict;
        message[@"district"] = district;
        message[@"province"] = province;
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        NSLog(@"readData - end");
    }];
}

- (BOOL) selectApplet: (SCARDHANDLE)hCard {
    BYTE selectCommand[] = { 0x00, 0xA4, 0x04, 0x00, 0x08, 0xA0, 0x00, 0x00, 0x00, 0x54, 0x48, 0x00, 0x01 };
    NSData *response = [self transmit:hCard commandApdu:[NSData dataWithBytes:selectCommand length:sizeof(selectCommand)]];
    if (response == nil) {
        return NO;
    }
    return YES;
}

- (NSString *) readCitizenId: (SCARDHANDLE) hCard {
    BYTE readCommand[] = { 0x80, 0xb0, 0x00, 0x04, 0x02, 0x00, 0x0d };
    NSData *readResponse = [self transmit:hCard commandApdu:[NSData dataWithBytes:readCommand length:sizeof(readCommand)]];
    if (readResponse == nil) {
        return nil;
    }
    
    BYTE getResponseCommand[] = { 0x00, 0xc0, 0x00, 0x00, 0x0d };
    NSData *response = [self transmit:hCard commandApdu:[NSData dataWithBytes:getResponseCommand length:sizeof(getResponseCommand)]];
    
    if (response.length < 2) {
        NSLog(@"SCardTransmit failed - wrong response length");
        return nil;
    }
    
    BYTE *responseBytes = malloc(response.length);
    [response getBytes:responseBytes length:response.length];
    responseBytes[response.length - 2] = '\0';
    
    NSString *citizenId = [NSString stringWithCString:(const char *)responseBytes encoding:NSASCIIStringEncoding];
    free(responseBytes);
    return citizenId;
}

- (NSString *) readPersonalInfo: (SCARDHANDLE) hCard {
    BYTE readCommand[] = { 0x80, 0xb0, 0x00, 0x11, 0x02, 0x00, 0xd1 };
    NSData *readResponse = [self transmit:hCard commandApdu:[NSData dataWithBytes:readCommand length:sizeof(readCommand)]];
    if (readResponse == nil) {
        return nil;
    }
    
    BYTE getResponseCommand[] = { 0x00, 0xc0, 0x00, 0x00, 0xd1 };
    NSData *response = [self transmit:hCard commandApdu:[NSData dataWithBytes:getResponseCommand length:sizeof(getResponseCommand)]];
    
    if (response.length < 2) {
        NSLog(@"SCardTransmit failed - wrong response length");
        return nil;
    }
    
    BYTE *responseBytes = malloc(response.length);
    [response getBytes:responseBytes length:response.length];
    responseBytes[response.length - 2] = '\0';
    
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinThai);
    NSString *personalInfo = [NSString stringWithCString:(const char *)responseBytes encoding:encoding];
    free(responseBytes);
    return personalInfo;
}

- (NSString *) readAddress:(SCARDHANDLE)hCard {
    BYTE readCommand[] = { 0x80, 0xb0, 0x15, 0x79, 0x02, 0x00, 0x64 };
    NSData *readResponse = [self transmit:hCard commandApdu:[NSData dataWithBytes:readCommand length:sizeof(readCommand)]];
    if (readResponse == nil) {
        return nil;
    }
    
    BYTE getResponseCommand[] = { 0x00, 0xc0, 0x00, 0x00, 0x64 };
    NSData *response = [self transmit:hCard commandApdu:[NSData dataWithBytes:getResponseCommand length:sizeof(getResponseCommand)]];
    
    if (response.length < 2) {
        NSLog(@"SCardTransmit failed - wrong response length");
        return nil;
    }
    
    BYTE *responseBytes = malloc(response.length);
    [response getBytes:responseBytes length:response.length];
    responseBytes[response.length - 2] = '\0';
    
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinThai);
    NSString *address = [NSString stringWithCString:(const char *)responseBytes encoding:encoding];
    free(responseBytes);
    return address;
}

- (NSString *) readIssuedExpired:(SCARDHANDLE)hCard {
    BYTE readCommand[] = { 0x80, 0xb0, 0x01, 0x67, 0x02, 0x00, 0x12 };
    NSData *readResponse = [self transmit:hCard commandApdu:[NSData dataWithBytes:readCommand length:sizeof(readCommand)]];
    if (readResponse == nil) {
        return nil;
    }
    
    BYTE getResponseCommand[] = { 0x00, 0xc0, 0x00, 0x00, 0x12 };
    NSData *response = [self transmit:hCard commandApdu:[NSData dataWithBytes:getResponseCommand length:sizeof(getResponseCommand)]];
    
    if (response.length < 2) {
        NSLog(@"SCardTransmit failed - wrong response length");
        return nil;
    }
    
    BYTE *responseBytes = malloc(response.length);
    [response getBytes:responseBytes length:response.length];
    responseBytes[response.length - 2] = '\0';
    
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinThai);
    NSString *issuedExpired = [NSString stringWithCString:(const char *)responseBytes encoding:encoding];
    free(responseBytes);
    return issuedExpired;
}

- (NSData *) transmit:(SCARDHANDLE)hCard commandApdu:(NSData *)commandApdu{
    SCARD_IO_REQUEST     ioRecvPci;
    BYTE *commandBytes = malloc(commandApdu.length);
    [commandApdu getBytes:commandBytes length:commandApdu.length];
    
    BYTE response[260];
    DWORD responseLength = sizeof(response);
    int res = SCardTransmit(hCard, SCARD_PCI_T0,
                  commandBytes, (DWORD)commandApdu.length, &ioRecvPci,
                  response, &responseLength);
    if (res != SCARD_S_SUCCESS) {
        free(commandBytes);
        
        NSLog(@"SCardTransmit failed: res %X", res);
        return nil;
    }
    free(commandBytes);
    return [NSData dataWithBytes:response length:responseLength];
}

- (NSArray *) listReadersByContext: (SCARDCONTEXT)context {
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

- (NSString *) formatDateFromIdCard:(NSString *)originalDate {
    int year = [[originalDate substringWithRange:NSMakeRange(0, 4)] intValue];
    int month = [[originalDate substringWithRange:NSMakeRange(4, 2)] intValue];
    int day = [[originalDate substringWithRange:NSMakeRange(6, 2)] intValue];
    
    NSDate *date = [self makeDateFromBuddhistYear:year month:month day:day];
    return [self formatDate:date format:@"yyyy-MM-dd"];
}

- (NSDate *) makeDateFromBuddhistYear: (int)year month:(int)month day:(int)day {
    NSDateComponents *dateComponent = [[NSDateComponents alloc] init];
    [dateComponent setYear:year];
    [dateComponent setMonth:month];
    [dateComponent setDay:day];
    
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierBuddhist];
    return [calendar dateFromComponents:dateComponent];
    return [NSDate date];
}

- (NSString *) formatDate: (NSDate *)date format:(NSString *)format {
    if (date == nil) {
        return nil;
    }
    NSLocale *locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:format];
    [dateFormatter setLocale:locale];
    return [dateFormatter stringFromDate:date];
}

@end
