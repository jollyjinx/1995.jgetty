/*  TEXT WAS MADE WITH 4*SPACE = 1*TAB

    program :   Voice.h
    version :   see the version.h file  
    date    :   Sat Oct  7 16:11:57 MET 1995
    purpose :   general Voice Object 
    author  :   by jolly ( who else )

*/

#import <Foundation/Foundation.h>

@interface Voice:NSObject
{

}

- (NSString *) number;
- (NSData *) twoBitAdpcm;
- setTwoBitAdpcm:(NSData *)data;

@end

