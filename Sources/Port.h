/*  TEXT WAS MADE WITH 4*SPACE = 1*TAB

    program :   Port.h
    version :   see the version.h file  
    date    :   Sat Oct  7 16:11:57 MET 1995
    author  :   by jolly ( who else )

*/


#import <mach/mach.h>
#import <Foundation/Foundation.h>

#import "LockFile.h"

@interface Port:NSObject
{
    NSUserDefaults *defaults;                 // UserDefaults object 

    int file;                                 // filedesciptor of the device beeing used
    LockFile *lockFile;                       // object used to create a lockfile like /usr/spool/uucp/LCK/LCK..cufa

@private
    NSConditionLock *writeLock;               // condition lock for writing : 0= not writing; 1=stopping ; 2=writing
    NSRecursiveLock *portLock;                // lock multiple access to the following variables
    volatile BOOL portIsConfigured;           // is set to YES if the port is configured ( ioctl'ed ) already
    volatile int ioctlSpeed;
    volatile int ioctlFlow;
    volatile int ioctlHangup;
}

-(void) _ioctl;


- initWithDevice:(NSString *)device;
-(void) dealloc;

-(BOOL) trylock;
-(void) unlock;
-(int) fileDescriptor;

-(void) setSpeed:(int)speed;
-(void) setDTR:(BOOL)current;
-(void) setFlowControl:(int)flowcontrol;
-(void) setHangup:(BOOL)hangup;


-(void) clearBuffers;
-(NSArray *) waitFor:(NSArray *)array maximumTime:(float)maxtime;
-(NSArray *) waitFor:(NSArray *)array maximumTime:(float)maxtime maximumLag:(float)lagtime;

- (void) stopWriting;
- (void) writeString:(NSString *)string;
- (void) writeData:(NSData *)data;


@end



