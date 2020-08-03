#import "ThaiIdCardCordovaPlugin.h"
#import <Cordova/CDVAvailability.h>
#include "ThaiIdCardReader.h"

@implementation ThaiIdCardCordovaPlugin {
    ThaiIdCardReader *idCardReader;
}

- (void)pluginInitialize {
    idCardReader = [[ThaiIdCardReader alloc] init];
}

- (void)listReaders:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        @try {
            NSLog(@"listReaders - begin");
            NSArray *readerList = [self->idCardReader listReaders];
            NSLog(@"listReaders - end");
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:readerList];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
        @catch (NSException *e) {
            NSLog(@"listReaders - error: %@", e.reason);
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:e.reason];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    }];
}

- (void)readData:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        @try {
            NSLog(@"readData - begin");
            NSDictionary *options = [command.arguments objectAtIndex:0];
            NSDictionary *message = [self->idCardReader readData:options];
            NSLog(@"readData - end");
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
        @catch (NSException *e) {
            NSLog(@"readData - error: %@", e.reason);
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:e.reason];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    }];
}

@end
