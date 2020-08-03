//
//  ThaiIdReader.h
//  ThaiIdReader
//
//  Created by NewTech on 31/7/2563 BE.
//  Copyright © 2563 NewTech. All rights reserved.
//

#ifndef ThaiIdReader_h
#define ThaiIdReader_h


@interface ThaiIdCardReader : NSObject {
}

- (instancetype)init;
- (NSArray *)listReaders;
- (NSDictionary *)readData:(NSDictionary *)options;
@end


#endif /* ThaiIdReader_h */
