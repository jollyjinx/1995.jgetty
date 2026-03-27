/*  TEXT WAS MADE WITH 4*SPACE = 1*TAB

    program :   Modem.h
    version :   see the version.h file  
    date    :   Sat Oct  7 16:11:57 MET 1995
    purpose :   distributed modem 
    author  :   by jolly ( who else )

*/


#import <mach/mach.h>
#import <Foundation/Foundation.h>

#import "Voice.h"
#import "Fax.h"
#import "Port.h"


@interface Modem:NSObject
{   
    NSUserDefaults *defaults;                         // User defaults object
    NSString *device;                                 // device name e.g. "fa" or "fb", needed to create a "/dev/tty.." on login 
    NSLock *modemInUseLock;                           // tells connected clients ( like when faxing ) that we are doing stuff
    Port *port;                                       // serial port
}


- (BOOL) isFaxModem;
- (BOOL) isVoiceModem;


-       initWithDevice:(NSString *)aDevice;
-(BOOL) ask:(NSString *)ask valid:(NSString *)valid invalid:(NSString *)invalid maximumTime:(float)time;
-(BOOL) ask:(NSString *)ask valid:(NSString *)valid invalid:(NSString *)invalid;

-(BOOL) reset;
-(void) waitOnLine;
-(int)  waitForNRings:(int)ringcount;
-(BOOL) dataCall;

- port;

- (int) sendFax:(Fax *)fax;
- (int) playVoice:(Voice *)voice;
- (int) recordVoice:(Voice *)voice;

@end
