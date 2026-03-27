/*  TEXT WAS MADE WITH 4*SPACE = 1*TAB

    program :   Port.m
    version :   see the version.h file  
    date    :   Sat Oct  7 16:11:57 MET 1995
    author  :   by jolly ( who else )

*/

#include <libc.h>

#import "Port.h"
#import "FastMatch.h"



@implementation Port:NSObject

- initWithDevice:(NSString *)device;
{
    NSMutableDictionary *dict;

    [super init];
    
    dict = [NSMutableDictionary dictionaryWithCapacity:20];
    [dict setObject:@"/usr/spool/uucp/LCK/LCK.." forKey:@"lockFilePrefix"];
    [dict setObject:@"NO" forKey:@"asciiLock"];
    [dict setObject:@".100" forKey:@"readInterval"];
    [dict setObject:@"4096" forKey:@"readSize"];
    [dict setObject:@"1024" forKey:@"writeSize"];
    [dict setObject:@"38400" forKey:@"PortSpeed"];
    defaults=[NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:dict];

    portLock = [[[NSRecursiveLock alloc] init] retain];
    writeLock = [[[NSConditionLock alloc] initWithCondition:0] retain];
    lockFile = [[[LockFile alloc] initWithFile:[[defaults objectForKey:@"lockFilePrefix"] stringByAppendingString:device]
                                  useASCIILock:[defaults boolForKey:@"asciiLock"]] retain];
    
        
    switch([defaults integerForKey:@"PortSpeed"])
    {
        case    57600:  ioctlSpeed=B57600;break;
        case    38400:  ioctlSpeed=B38400;break;
        case    19200:  ioctlSpeed=B19200;break;
        case    14400:  ioctlSpeed=B14400;break;
        case     9600:  ioctlSpeed=B9600;break;
        default      :  NSLog(@"weird default setting - using 38400 as speed\n"); ioctlSpeed=B38400;
    }
    
    portIsConfigured=NO;
    ioctlFlow=TANDEM|RAW;
    ioctlHangup=0;


    file=open([[@"/dev/" stringByAppendingString:device] cString], O_RDWR);
    if(-1 == file)
    {
        NSLog(@"Can't open %s\n",[[@"/dev/" stringByAppendingString:device] cString]);
        [self release];
        return nil;
    }
    
    return self;
}


-(void) dealloc
{
    if(-1 !=file) close(file);
    [lockFile release];
    [portLock release];
    [writeLock release];
    [super dealloc];
}





-(int) fileDescriptor
{
    return file;
}

-(BOOL) trylock
{
    return [lockFile trylock];
}

-(void) unlock
{
    [portLock lock];
    [self stopWriting];
    portIsConfigured = NO;
    [portLock unlock];
    [lockFile unlock];
}

-(void) _ioctl
{
    struct  sgttyb  tdis;

    [portLock lock];
    if(YES == portIsConfigured)
    {
        [portLock unlock];
        return;
    }

    [lockFile lock];
    
    if( ioctl(file,TIOCGETP,&tdis) == -1 ) NSLog(@"Can't execute ioctl TIOCGETP\n");
    tdis.sg_ispeed=ioctlSpeed;
    tdis.sg_ospeed=ioctlSpeed;
    tdis.sg_flags=ioctlFlow | ioctlHangup;
    if( ioctl(file,TIOCSETP,&tdis) == -1 ) NSLog(@"Can't execute ioctl TIOCSETP\n");

    portIsConfigured = YES;
    [portLock unlock];  
}


-(void) setSpeed:(int)speed
{
    [portLock lock];
    ioctlSpeed = speed;
    portIsConfigured = NO;
    [portLock unlock];  
}


-(void) setDTR:(BOOL)current;
{
    [portLock lock];
    [self _ioctl];

    if( !current && ioctl(file,TIOCCDTR,NULL) == -1 ) NSLog(@"Can't execute ioctl TIOCCDTR\n");
    if( current && ioctl(file,TIOCSDTR,NULL) == -1 ) NSLog(@"Can't execute ioctl TIOCSDTR\n");
    
    [portLock unlock];
}


-(void) setFlowControl:(int)flowcontrol
{
    [portLock lock];
    ioctlFlow = flowcontrol;
    portIsConfigured = NO;
    [portLock unlock];  
}


-(void) setHangup:(BOOL)hangup
{
    [portLock lock];
    if(NO == hangup)
        ioctlHangup=NOHANG;
    else
        ioctlHangup=0;
    portIsConfigured = NO;
    [portLock unlock];
}


-(void) clearBuffers
{
    static char remove[1024];
    int nfds;
    fd_set fdset;
    struct timeval selecttimeout;
    
    selecttimeout.tv_sec=0;
    selecttimeout.tv_usec=0;
    nfds=1;
    FD_ZERO(&fdset);
    FD_SET(file,&fdset);

    [portLock lock];
    [self _ioctl];
    
    if( 1==select(nfds, &fdset, NULL, NULL, &selecttimeout) )
    {
        read(file,remove,1024);
    }
    [portLock unlock];
}



-(NSArray *) waitFor:(NSArray *)array maximumTime:(float)time
{
    return [self waitFor:array maximumTime:(float)time maximumLag:(float)time];
}



-(NSArray *) waitFor:(NSArray *)array maximumTime:(float)maxtime maximumLag:(float)lagtime
{
    int                 readinterval;
    int                 readsize;
    static u_char       *readbuffer=NULL;
    static int          length;     

    NSMutableData       *readObject;
    FastMatch           *matcher;
    NSDate *maxTime=[NSDate dateWithTimeIntervalSinceNow:maxtime];
    NSDate *lagTime=[NSDate dateWithTimeIntervalSinceNow:lagtime];
    
    int             nfds;
    fd_set          fdset;
    struct timeval  selecttimeout;
    
    selecttimeout.tv_sec=0;
    selecttimeout.tv_usec=0;
    nfds=1;
    

    [portLock lock];
    [self _ioctl];
    

    readsize    =[defaults integerForKey:@"readSize"];
    readinterval=[defaults floatForKey:@"readInterval"];  
    readObject  =[[NSMutableData alloc] initWithCapacity:readsize];
    matcher     =[[FastMatch alloc] init];
    if(NULL==readbuffer)
    {
        readbuffer=(u_char *)malloc(readsize);
    }
    
    [matcher setMatchingStrings:array];
    [matcher reset];
    
    do
    {
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:readinterval]];
        FD_ZERO(&fdset);
        FD_SET(file,&fdset);
        if(1==select(nfds, &fdset, NULL, NULL, &selecttimeout))
        {
            length=read(file, readbuffer, readsize);
            if(length>0)
            {
                int match;
                lagTime=[NSDate dateWithTimeIntervalSinceNow:lagtime];
                
                if(0 <= (match = [matcher matchWithBuffer:readbuffer size:length]))
                {
                    [readObject appendBytes:readbuffer length:(match>>8)];
                    [portLock unlock];
                    return [[NSMutableArray alloc] initWithObjects:[NSNumber numberWithInt:(match & 0xff)], readObject, nil];
                }
                else
                {
                    [readObject appendBytes:readbuffer length:length];
                }
            }
            else
            {
                NSLog(@"Reading Error ( probably signal occured during read ). This is non fatal.\n");
            }
        }
        if(NSOrderedAscending==[[NSDate date] compare:lagTime])
        {
            [portLock unlock];
            return [[NSMutableArray alloc] initWithObjects:[NSNumber numberWithInt:-1], readObject, nil];
        }
    }
    while(NSOrderedAscending==[[NSDate date] compare:maxTime]);
    [portLock unlock];
    return [[NSMutableArray alloc] initWithObjects:[NSNumber numberWithInt:-2], readObject, nil];
}



-(void) stopWriting
{
    if( YES == [writeLock tryLockWhenCondition:2])
    {
        [writeLock unlockWithCondition:1];
        [writeLock lockWhenCondition:0];
        [writeLock unlock];
    }
}


-(void) writeString:(NSString *)string;
{
    NSData *stringData;
    
    stringData = [NSData dataWithBytesNoCopy:(char *)[string cString] length:[string cStringLength]];
    [self writeData:stringData];
}



-(void) writeData:(NSData *)data;
{
    int         initiallength;
    int         writesize;
    const void  *bytes;

    [writeLock lockWhenCondition:0];
    [writeLock unlockWithCondition:2];

    [self _ioctl];    

    bytes           =[data bytes];
    initiallength   =[data length];
    writesize       =[defaults integerForKey:@"writeSize"];
    
    while(initiallength>0)
    {
        if(1 == [writeLock condition])
        {
            initiallength=0;
        }
        else
        {
            NSLog(@"Writing :%s %d\n",bytes,initiallength);
            write(file,bytes,initiallength%writesize);
            initiallength-=writesize;
            bytes+=writesize;
        }
    }

    [writeLock lock];
    [writeLock unlockWithCondition:0];
        
    return;
}


@end
