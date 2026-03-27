/*  TEXT WAS MADE WITH 4*SPACE = 1*TAB

    program :   Fax.h
    version :   see the version.h file  
    date    :   Sat Oct  7 16:11:57 MET 1995
    purpose :   general Voice Object 
    author  :   by jolly ( who else )

*/

#import <Foundation/Foundation.h>

@interface Fax:NSObject
{

}

- (NSString *) senderPhonenumber;
- (NSString *) receiverPhonenumber;

- (BOOL) highResolution;

- (NSData *) class2Data;
- (NSData *) class2DData;
- (void) setClass2Data:(NSData *)data ;
- (void) setClass2DData:(NSData *)data ;

@end

