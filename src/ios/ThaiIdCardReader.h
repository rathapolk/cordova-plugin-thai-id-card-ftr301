//
//  ThaiIdCardReader.h
//  ThaiIdCardReader
//
//  Created by NewTech on 31/7/2563 BE.
//  Copyright © 2563 NewTech. All rights reserved.
//

#ifndef ThaiIdCardReader_h
#define ThaiIdCardReader_h


@interface ThaiIdCardReader : NSObject {
}

- (instancetype)init;
- (NSArray *)listReaders;
- (NSDictionary *)readData:(NSDictionary *)options;
@end


#endif /* ThaiIdCardReader_h */
