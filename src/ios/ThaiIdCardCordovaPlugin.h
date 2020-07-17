#import <Cordova/CDVPlugin.h>

@interface ThaiIdCardCordovaPlugin : CDVPlugin {
}

- (void)listReaders:(CDVInvokedUrlCommand *)command;
- (void)readData:(CDVInvokedUrlCommand *)command;
@end