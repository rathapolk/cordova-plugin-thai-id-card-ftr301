//
//  ThaiIdCardReader.m
//  ThaiIdCardReader
//
//  Created by NewTech on 31/7/2563 BE.
//  Copyright © 2563 NewTech. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "ThaiIdCardReader.h"
#if __APPLE__
    #include <TargetConditionals.h>
    #if TARGET_OS_IPHONE
        #include "winscard.h"
    #elif TARGET_OS_SIMULATOR
        #include "winscard.h"
    #elif TARGET_OS_OSX
        #import <PCSC/winscard.h>
        #import <PCSC/wintypes.h>
    #endif // TARGET_OS_MAC
#endif // __APPLE__

@implementation ThaiIdCardReader {
    NSStringEncoding thaiStringEncoding;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        thaiStringEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinThai);
    }
    return self;
}

- (NSArray *)listReaders {
    SCARDCONTEXT context;
    int res = SCardEstablishContext(SCARD_SCOPE_SYSTEM, NULL, NULL, &context);
    if (res != SCARD_S_SUCCESS) {
        // Mac os - remove App SandBox in Signing & Capabilities
        NSLog(@"SCardEstablishContext failed: res %X", res);
        return nil;
    }
    
    NSArray *readerList = [self listReadersWithContext:context];
    SCardReleaseContext(context);
    return readerList;
}

- (NSDictionary *)readData:(NSDictionary *)options {
    NSString *readerName = options[@"readerName"];
    
    BOOL readCitizenId = options[@"readCitizenId"] == nil? YES : [(NSNumber *)options[@"readCitizenId"] boolValue];
    BOOL readPersonal = options[@"readPersonal"] == nil? YES : [(NSNumber *)options[@"readPersonal"] boolValue];
    BOOL readAddress = options[@"readAddress"] == nil? YES : [(NSNumber *)options[@"readAddress"] boolValue];
    BOOL readIssuedExpired = options[@"readIssuedExpired"] == nil? YES : [(NSNumber *)options[@"readIssuedExpired"] boolValue];
    BOOL readPhoto = [(NSNumber *)options[@"readPhoto"] boolValue];
    
    SCARDCONTEXT context = 0;
    int res = SCardEstablishContext(SCARD_SCOPE_SYSTEM, NULL, NULL, &context);
    if (res != SCARD_S_SUCCESS) {
        NSString *errorMessage = [NSString stringWithFormat:@"SCardEstablishContext failed: res %X", res];
        NSLog(@"%@", errorMessage);
        
        NSException *exception = [NSException exceptionWithName:@"ThaiIdReaderException" reason:errorMessage userInfo:nil];
        @throw exception;
    }
    
    if (readerName == nil) {
        NSArray *readerList = [self listReadersWithContext:context];
        if (readerList.count == 0) {
            SCardReleaseContext(context);
            
            NSString * errorMessage = @"No reader found!";
            NSException *exception = [NSException exceptionWithName:@"ThaiIdReaderException" reason:errorMessage userInfo:nil];
            @throw exception;
        }
        readerName = readerList[0];
    }
    
    SCARDHANDLE hCard = 0;
    DWORD activeProtocol = 0;
    res = SCardConnect(context, readerName.UTF8String, SCARD_SHARE_SHARED, SCARD_PROTOCOL_T0, &hCard, &activeProtocol);
    if (res != SCARD_S_SUCCESS) {
        [self disconnectAndReleaseContext:hCard context:context];
        
        NSLog(@"SCardConnect failed: res %d", res);
        NSString *errorMessage = @"Card not present.";
        NSException *exception = [NSException exceptionWithName:@"ThaiIdReaderException" reason:errorMessage userInfo:nil];
        @throw exception;
    }
    
    // Select Applet
    if ([self selectApplet:hCard] == nil) {
        [self disconnectAndReleaseContext:hCard context:context];
        
        NSLog(@"SCardTransmit failed: res %X", res);
        NSString *errorMessage = @"This card may not be Thai id.";
        NSException *exception = [NSException exceptionWithName:@"ThaiIdReaderException" reason:errorMessage userInfo:nil];
        @throw exception;
    }
    
    // read citizen id
    NSString *citizenId = nil;
    if (readCitizenId) {
        citizenId = [self readCitizenId:hCard];
        if (citizenId == nil) {
            [self disconnectAndReleaseContext:hCard context:context];
            
            NSString *errorMessage = @"Reading citizen id failed.";
            NSException *exception = [NSException exceptionWithName:@"ThaiIdReaderException" reason:errorMessage userInfo:nil];
            @throw exception;
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
            [self disconnectAndReleaseContext:hCard context:context];
            
            NSString *errorMessage = @"Reading personal info failed.";
            NSException *exception = [NSException exceptionWithName:@"ThaiIdReaderException" reason:errorMessage userInfo:nil];
            @throw exception;
        }
        
        NSString *personalInfoTh = [[personalInfo substringWithRange:NSMakeRange(0, 100)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *personalInfoEn = [[personalInfo substringWithRange:NSMakeRange(100, 100)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
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
            [self disconnectAndReleaseContext:hCard context:context];
            
            NSString *errorMessage = @"Reading address failed.";
            NSException *exception = [NSException exceptionWithName:@"ThaiIdReaderException" reason:errorMessage userInfo:nil];
            @throw exception;
        }
        NSString *trimmedAddress = [address stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSArray *addressComponents = [trimmedAddress componentsSeparatedByString:@"#"];
        if (addressComponents.count >= 8) {
            houseNo = [addressComponents[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            village = [addressComponents[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            lane = [addressComponents[2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            road = [addressComponents[3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            subdistrict = [addressComponents[5] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            district = [addressComponents[6] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            province = [addressComponents[7] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            
            NSMutableString *addressLineBuilder = [NSMutableString stringWithCapacity:100];
            [addressLineBuilder appendString:houseNo];
            [addressLineBuilder appendString:@" "];
            [addressLineBuilder appendString:village];
            [addressLineBuilder appendString:@" "];
            [addressLineBuilder appendString:lane];
            [addressLineBuilder appendString:@" "];
            [addressLineBuilder appendString:road];
            [addressLineBuilder appendString:@" "];
            [addressLineBuilder appendString:subdistrict];
            [addressLineBuilder appendString:@" "];
            [addressLineBuilder appendString:district];
            [addressLineBuilder appendString:@" "];
            [addressLineBuilder appendString:province];
            addressLine = addressLineBuilder;
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
    
    // read photo
    NSString *photoBase64 = nil;
    if (readPhoto) {
        NSData *photo = [self readPhoto:hCard];
        if (photo != nil) {
            photoBase64 = [photo base64EncodedStringWithOptions:0];
        }
    }
    [self disconnectAndReleaseContext:hCard context:context];
    
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
    message[@"photoBase64"] = photoBase64;
    return message;
}

- (NSData *)selectApplet:(SCARDHANDLE)hCard {
    BYTE selectCommand[] = { 0x00, 0xA4, 0x04, 0x00, 0x08, 0xA0, 0x00, 0x00, 0x00, 0x54, 0x48, 0x00, 0x01 };
    NSData *response = [self transmit:hCard commandApdu:[NSData dataWithBytes:selectCommand length:sizeof(selectCommand)]];
    if (![self responseOk:response]) {
        return nil;
    }
    return response;
}

- (NSString *)readCitizenId:(SCARDHANDLE) hCard {
    const int CITIZEN_ID_LENGTH = 13;
    BYTE command[] = { 0x80, 0xb0, 0x00, 0x04, 0x02, 0x00, 0x0d };
    NSData *response = [self transmitAndGetResponse:hCard commandApdu:[NSData dataWithBytes:command length:sizeof(command)]];
    if (![self responseOk:response]) {
        return nil;
    }
    if (response.length != CITIZEN_ID_LENGTH + 2) {
        NSLog(@"SCardTransmit failed - wrong thai id length");
        return nil;
    }
    NSString *citizenId = [[NSString alloc] initWithBytesNoCopy:(void *)response.bytes length:(response.length - 2) encoding:thaiStringEncoding freeWhenDone:NO];
    return citizenId;
}

- (NSString *)readPersonalInfo:(SCARDHANDLE) hCard {
    BYTE command[] = { 0x80, 0xb0, 0x00, 0x11, 0x02, 0x00, 0xd1 };
    NSData *response = [self transmitAndGetResponse:hCard commandApdu:[NSData dataWithBytes:command length:sizeof(command)]];
    if (![self responseOk:response]) {
        return nil;
    }
    NSString *personalInfo = [[NSString alloc] initWithBytesNoCopy:(void *)response.bytes length:(response.length - 2) encoding:thaiStringEncoding freeWhenDone:NO];
    return personalInfo;
}

- (NSString *)readAddress:(SCARDHANDLE)hCard {
    BYTE command[] = { 0x80, 0xb0, 0x15, 0x79, 0x02, 0x00, 0x64 };
    NSData *response = [self transmitAndGetResponse:hCard commandApdu:[NSData dataWithBytes:command length:sizeof(command)]];
    if (![self responseOk:response]) {
        return nil;
    }
    NSString *address = [[NSString alloc] initWithBytesNoCopy:(void *)response.bytes length:(response.length - 2) encoding:thaiStringEncoding freeWhenDone:NO];
    return address;
}

- (NSString *)readIssuedExpired:(SCARDHANDLE)hCard {
    BYTE command[] = { 0x80, 0xb0, 0x01, 0x67, 0x02, 0x00, 0x12 };
    NSData *response = [self transmitAndGetResponse:hCard commandApdu:[NSData dataWithBytes:command length:sizeof(command)]];
    if (![self responseOk:response]) {
        return nil;
    }
    NSString *issuedExpired = [[NSString alloc] initWithBytesNoCopy:(void *)response.bytes length:(response.length - 2) encoding:thaiStringEncoding freeWhenDone:NO];
    return issuedExpired;
}

- (NSData *)readPhoto:(SCARDHANDLE)hCard {
    const int MAX_CHUNK = 20;
    BYTE p1 = 0x01;
    BYTE p2 = 0x7B;
    NSOutputStream *stream = [NSOutputStream outputStreamToMemory];
    [stream open];
    for (int i = 0; i < MAX_CHUNK; i++) {
        BYTE command[] = { 0x80, 0xB0, p1, p2, 0x02, 0x00, 0xFF };
        NSData *response = [self transmitAndGetResponse:hCard commandApdu:[NSData dataWithBytes:command length:sizeof(command)]];
        
        if (response.length - 2 == 0) {
            break;
        }
        [stream write:response.bytes maxLength:(response.length - 2)];
        p1 += 1;
        p2 -= 1;
    }
    NSData *contents = [stream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    [stream close];
    return contents;
}

- (NSData *)transmit:(SCARDHANDLE)hCard commandApdu:(NSData *)commandApdu {
    SCARD_IO_REQUEST ioRecvPci;
    BYTE responseBytes[260];
    DWORD responseLength = sizeof(responseBytes);
    int res = SCardTransmit(hCard, SCARD_PCI_T0,
                  commandApdu.bytes, (DWORD)commandApdu.length, &ioRecvPci,
                  responseBytes, &responseLength);
    if (res != SCARD_S_SUCCESS) {
        NSLog(@"SCardTransmit failed: res %X", res);
        return nil;
    }
    if (responseLength < 2) {
        NSLog(@"SCardTransmit failed - wrong response length");
        return nil;
    }
    return [NSData dataWithBytes:responseBytes length:responseLength];
}

- (NSData *)transmitAndGetResponse:(SCARDHANDLE)hCard commandApdu:(NSData *)commandApdu {
    NSData *response = [self transmit:hCard commandApdu:commandApdu];
    if (response == nil) {
        return nil;
    }
    
    BYTE sw1 = ((BYTE *)response.bytes)[response.length - 2];
    BYTE sw2 = ((BYTE *)response.bytes)[response.length - 1];
    if (sw1 != 0x61) {
        return response;
    }
    
    BYTE getResponseCommand[] = { 0x00, 0xc0, 0x00, 0x00, sw2 };
    return [self transmit:hCard commandApdu:[NSData dataWithBytes:getResponseCommand length:sizeof(getResponseCommand)]];
}

- (BOOL)responseOk:(NSData *)response {
    if (response == nil) {
        return NO;
    }
    if (response.length < 2) {
        return NO;
    }
    BYTE sw1 = ((BYTE *)response.bytes)[response.length - 2];
    BYTE sw2 = ((BYTE *)response.bytes)[response.length - 1];
    
    if (sw1 == 0x61) {
        return YES;
    }
    if (sw1 == 0x90 || sw2 == 0x00) {
        return YES;
    }
    return NO;
}

- (NSArray *)listReadersWithContext:(SCARDCONTEXT)context {
    DWORD chReaders = 0;
    int res = SCardListReaders(context, NULL, NULL, &chReaders);
    if (res != SCARD_S_SUCCESS) {
        NSLog(@"SCardListReaders failed: res %X", res);
        return [NSMutableArray arrayWithCapacity:0];
    }
    
    LPSTR readers = malloc(sizeof(char)*chReaders);
    res = SCardListReaders(context, NULL, readers, &chReaders);
    if (res != SCARD_S_SUCCESS) {
        NSLog(@"SCardListReaders failed: res %X", res);
        return [NSMutableArray arrayWithCapacity:0];
    }
    NSArray *readerList = [self extractReadersFromString:readers count:chReaders];
    free(readers);
    return readerList;
}

- (void)disconnectAndReleaseContext:(SCARDHANDLE)hCard context:(SCARDCONTEXT)context {
    if (hCard != 0) {
        SCardDisconnect(hCard, SCARD_UNPOWER_CARD);
    }
    if (context != 0) {
        SCardReleaseContext(context);
    }
}

- (NSArray *)extractReadersFromString:(LPSTR)str count:(DWORD)count {
    NSMutableArray *list = [[NSMutableArray alloc]initWithCapacity:1];
    
    int startIndex = 0;
    for (int index = 0; index < count - 1; index++) {
        char ch = *(LPSTR)(str + index);
        if (ch == '\0' && index != startIndex) {
            NSString *name = [NSString stringWithCString:(LPSTR)(str + startIndex) encoding:NSASCIIStringEncoding];
            [list addObject:name];
            startIndex = index + 1;
        }
    }
    return list;
}

- (NSString *)formatDateFromIdCard:(NSString *)originalDate {
    int year = [[originalDate substringWithRange:NSMakeRange(0, 4)] intValue];
    int month = [[originalDate substringWithRange:NSMakeRange(4, 2)] intValue];
    int day = [[originalDate substringWithRange:NSMakeRange(6, 2)] intValue];
    
    NSDate *date = [self makeDateFromBuddhistYear:year month:month day:day];
    return [self formatDate:date format:@"yyyy-MM-dd"];
}

- (NSDate *)makeDateFromBuddhistYear:(int)year month:(int)month day:(int)day {
    NSDateComponents *dateComponent = [[NSDateComponents alloc] init];
    [dateComponent setYear:year];
    [dateComponent setMonth:month];
    [dateComponent setDay:day];
    
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierBuddhist];
    return [calendar dateFromComponents:dateComponent];
    return [NSDate date];
}

- (NSString *)formatDate:(NSDate *)date format:(NSString *)format {
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
