/*  TEXT WAS MADE WITH 4*SPACE = 1*TAB

    program :   LockFile.h
    version :   see the version.h file
    date    :
    author  :   by jolly ( who else )

*/

#import <Foundation/Foundation.h>

@interface LockFile:NSObject
{
    NSString *lockFile;                                  // Name of the file to lock "/usr/spool/uucp/LCK/LCK..cufa"
    BOOL asciilock;                                      // do we have to write the (int) or a string into the lockfile
    NSRecursiveLock *lock;                               // lock use of islocked variable
    volatile BOOL islocked;                              // if the port is already locked
}

- initWithFile:(NSString *)aLockFileName useASCIILock:(BOOL)aBool;

-(BOOL) isLocked;
-(void) lock;
-(BOOL) trylock;
-(void) unlock;

@end