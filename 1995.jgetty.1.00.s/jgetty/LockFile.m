/*  TEXT WAS MADE WITH 4*SPACE = 1*TAB

    program :   LockFile.h
    version :   see the version.h file
    date    :
    author  :   by jolly ( who else )

*/

#import <libc.h>
#import <sys/file.h>
#import <sys/ioctl.h>

#import "LockFile.h"


@implementation LockFile:NSObject

- initWithFile:(NSString *)aLockFileName useASCIILock:(BOOL)aBool
{
    [super init];
    islocked = NO;
    asciilock = aBool;
    lockFile = [aLockFileName retain];
    lock = [[NSRecursiveLock alloc] init];

    return self;
}



-(void) dealloc
{
    [self unlock];
    [lockFile release];
    [super dealloc];
}



-(BOOL) isLocked;
{
    BOOL ret;

    [lock lock];                                                                                // this is for multiple threads
    ret=islocked;
    [lock unlock];
    
    return ret;
}



-(void) lock;
{
    [lock lock];
     while( ![self trylock] )
    {
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:.500]];
    }
    [lock unlock];
}



-(BOOL) trylock;
{
    char    buffer[11];
    int     pid,feil;

    if(YES == [self isLocked])
        return YES;

    [lock lock];

    islocked = NO;

    if( -1 == (feil=open([lockFile cString],O_RDWR|O_CREAT|O_EXCL, 0660)))                      // In case the lockfile exists
    {
        if( -1 == (feil=open([lockFile cString], O_RDWR,0)) )                                   // try to open the lockfile
        {
            NSLog(@"Can't open uucplock but it's there\n");
            [lock unlock];
            return 0;
        }

        if( -1 == flock(feil, LOCK_EX | LOCK_NB) )                                              // try to f-lock the file
        {
            NSLog(@"File is flock(2)-ed after opening\n");
            [lock unlock];
            return 0;
        }

        if( sizeof(pid) < read(feil, buffer, sizeof(buffer)) )                              // read the lockfile
        {
            pid = atoi(buffer);
        }
        else
        {
            lseek(feil, 0, L_SET);
            if( sizeof(pid) != read(feil, &pid, sizeof(pid)) )
            {
                flock(feil,LOCK_UN);
                close(feil);
                NSLog(@"Can't read uucplock but it's there\n");
                [lock unlock];
                return 0;
            }
        }

        if( pid == getpid() )                                                                  // file is locked if our pid is in there
        {
            flock(feil,LOCK_UN);
            close(feil);
            islocked = YES;
            [lock unlock];
            return 1;
        }

        if( 0 == kill(pid, 0) )                                                               // If somebody else is usesing the lock try
        {                                                                                     // to figure out if that process still exists
            flock(feil,LOCK_UN);
            close(feil);
            [lock unlock];
            return 0;
        }
    }                                                                                         // lockfile did not exist and we created it
    else
    {
        if( -1 == flock(feil, LOCK_EX | LOCK_NB) )                                            // f-lock the file
        {
            NSLog(@"File is flock(2)-ed after creation\n");
            [lock unlock];
            return 0;
        }
    }

    if (lseek(feil, 0L, L_SET) < 0)                                                           // rewind
    {
        NSLog(@"Can't seek uucplock but it's there\n");
        close(feil);
    }

    pid = getpid();

    if( YES == asciilock )                                                                   // write asciilock or integer lock
    {                                                                                        // depending ond defaults database
        sprintf(buffer,"%10d",pid);
        write(feil,buffer,sizeof(buffer));
    }
    else
    {
        write( feil, &pid, sizeof(pid) );
    }

    flock(feil,LOCK_UN);
    close(feil);
    [lock unlock];

    return [self trylock];                                                                  // this is not recursive !!! just get's called once
}



-(void) unlock;
{
    [lock lock];
    if(YES == islocked)
    {
        unlink([lockFile cString]);
    }
    islocked = NO;
    [lock unlock];
}


@end
