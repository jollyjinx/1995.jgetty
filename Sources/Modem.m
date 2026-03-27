/*  TEXT WAS MADE WITH 4*SPACE = 1*TAB

    program :   Modem.h
    version :   see the version.h file  
    date    :   Sat Oct  7 16:11:57 MET 1995
    purpose :   distributed modem 
    author  :   by jolly ( who else )

*/

#import <Foundation/Foundation.h>
#import <sys/types.h>
#import <libc.h>
#import <string.h>

#import "ModemServerProtocol.h"
#import "Voice.h"
#import "Fax.h"
#import "Port.h"
#import "Modem.h"



@implementation Modem:NSObject


- (BOOL) isFaxModem
{
    return [defaults boolForKey:@"isFaxModem"];
}

-(BOOL) isVoiceModem
{
    return [defaults boolForKey:@"isVoiceModem"];
}


- initWithDevice:(NSString *)aDevice 
{   
    NSMutableDictionary *dict;

    [super init];
    
    dict=[NSMutableDictionary dictionaryWithCapacity:20];
    [dict setObject:@""                         forKey:@"dialPrefix"];
    [dict setObject:@""                         forKey:@"modemDictionary"];
    [dict setObject:MODEM_ServerName            forKey:@"modemServerName"];
    [dict setObject:MODEM_ServerHost            forKey:@"modemServerHost"];
    [dict setObject:MODEM_ClientName            forKey:@"modemClientName"];
    [dict setObject:MODEM_ClientHost            forKey:@"modemClientHost"];
    [dict setObject:@"/usr/etc/getty"           forKey:@"getty"];
    [dict setObject:@"std.38400"                forKey:@"gettyarg"];
    [dict setObject:@"ATZS0=0"                  forKey:@"ModemResetString"];
    [dict setObject:@"1.000"                    forKey:@"ModemCommandReplytime"];
    [dict setObject:@"60.000"                   forKey:@"ModemMaximumTimeToConnect"];
    [dict setObject:@"7.000"                    forKey:@"ModemMaximumTimeBetweenRings"];
    [dict setObject:@"4"                        forKey:@"ModemRingCount"];
    [dict setObject:@"0"                        forKey:@"DEBUG"];
    defaults=[NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:dict];

    modemInUseLock=[[NSLock alloc] init];

    if(! [aDevice hasPrefix:@"/dev/ttyd"] )
    {
        NSLog(@"Port has to have /dev/ttyd as prefix\n");
        [super dealloc];
        return nil;
    }
    device=[aDevice substringFromIndex:[@"/dev/ttyd" length]];

    if(! (port=[[Port alloc] initWithDevice:[@"cu" stringByAppendingString:device]] ))
    {
        NSLog(@"Can't create Port %@\n",[@"cu" stringByAppendingString:device]);
        [super dealloc];
        return nil;
    }

    {
        NSConnection *connection;

        connection = [NSConnection defaultConnection];
        [connection setRootObject:self];
        if( NO == [connection registerName:[defaults objectForKey:@"modemClientName"]])
            NSLog(@"Can't create server in Modem object\n");
    }

    [modemInUseLock retain];
    [port retain];
    
    return self;
}

-(void) dealloc
{
    [modemInUseLock release];
    [port release];
    [super dealloc];
}


-(BOOL) ask:(NSString *)ask valid:(NSString *)valid invalid:(NSString *)invalid maximumTime:(float)time
{
    NSArray *answers;
    NSArray *reply;
    
    answers = [[NSMutableArray alloc] initWithObjects:valid,invalid,nil];
    [port writeString:ask];
    [port writeString:@"\r\n"];
    reply = [port waitFor:answers maximumTime:time];
    if(1 < [defaults integerForKey:@"DEBUG"])
        NSLog(@"Got answer (%@) :%@ %s\n",[reply objectAtIndex:0],[reply objectAtIndex:1],[[reply objectAtIndex:1] bytes]);
    if(0 == [[reply objectAtIndex:0] intValue]) return YES;
    return NO;
}

-(BOOL) ask:(NSString *)ask valid:(NSString *)valid invalid:(NSString *)invalid;
{
    return [self ask:ask valid:valid invalid:invalid maximumTime:[defaults floatForKey:@"ModemCommandReplytime" ]];
}





-(BOOL) reset
{   
    int i=10;

    [port setDTR:NO];
    [port writeString:@"\x10\x03\n\x10\x03\0x10\r\nYYY"];
    [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.500]];
    [port setDTR:YES];
    [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.500]];
    [port clearBuffers];

    while(i--)
    {
        if( [self ask:[defaults objectForKey:@"ModemResetString"] valid:@"OK" invalid:@"ERROR"] )
        {
            if([defaults integerForKey:@"DEBUG"]) NSLog(@"Modem resetted\n");
            return YES;
        }
    }
    if([defaults integerForKey:@"DEBUG"]) NSLog(@"ModemObject was not able to reset the modem with string: %@\n",[defaults objectForKey:@"ModemResetString"]);
            
    return NO;
}


-(void) waitOnLine
{
    id <ModemServerProtocol>    modemServer;

    [port clearBuffers];
    {
        int                         nfds=1;
        fd_set                      fdset;
        
        FD_ZERO(&fdset);
        FD_SET([port fileDescriptor],&fdset);
        [port unlock];
        select(nfds,&fdset,NULL,NULL,NULL);
    }
    
    [modemInUseLock lock];
    if([defaults integerForKey:@"DEBUG"]) NSLog(@"Something on the line\n");
    if(![port trylock])
    {
        if([defaults integerForKey:@"DEBUG"]) NSLog(@"Modem used by other process - waiting\n");
        [modemInUseLock unlock];
       return;
    }
    
    modemServer=(id)[NSConnection rootProxyForConnectionWithRegisteredName:[defaults objectForKey:@"modemServerName"]
                                                                      host:[defaults objectForKey:@"modemServerHost"]];
    if(modemServer)
    {
        [modemServer dataOnLine:self];
    }
    else
    {
        if([defaults integerForKey:@"ModemRingCount"] == [self waitForNRings:[defaults integerForKey:@"ModemRingCount"]])
            [self dataCall];
    }  
    [modemInUseLock unlock];
    
    return;
}


-(int) waitForNRings:(int)ringcount
{
    NSArray *answers;
    NSArray *reply;
    int     momrings=0;

    answers=[[NSMutableArray alloc] initWithObjects:@"RING",@"CONNECT",@"OK",@"BUSY",@"ERROR",@"NO CARRIER",@"HANGUP",nil];
    while(momrings<ringcount)
    {
        reply=[port waitFor:answers maximumTime:[defaults floatForKey:@"ModemMaximumTimeBetweenRings"] ];
        
        if(1<[defaults integerForKey:@"DEBUG"])
            NSLog(@"Got answer (%@) :%@ %s\n",[reply objectAtIndex:0],[reply objectAtIndex:1],[[reply objectAtIndex:1] bytes]);
        switch([[reply objectAtIndex:0] intValue])
        {
            case 0  :   momrings++;break;
            default :   return momrings;
        }
    }
    return momrings;    
}



-(BOOL) dataCall
{
    NSArray *answers;
    NSArray *reply;

    
    if(! [self ask:@"ATA" valid:@"CONNECT" invalid:@"NO CARRIER" maximumTime:[defaults floatForKey:@"ModemMaximumTimeToConnect"]] )
    {
        NSLog(@"Didn't get a ATA reply\n");
        return NO;
    }
    
    [port writeString:@"+++"];  
    answers=[[NSMutableArray alloc] initWithObjects:@"OK",@"CONNECT",@"BUSY",@"ERROR",@"NO CARRIER",@"HANGUP",nil];
    reply=[port waitFor:answers maximumTime:[defaults floatForKey:@"ModemMaximumTimeBetweenRings"] ];
    if(0!=[[reply objectAtIndex:0] intValue] )
    {
        NSLog(@"Didn't get a +++ reply\n");
        return NO;
    }
    if(! [self ask:@"ATS2=255" valid:@"OK" invalid:@"ERROR" maximumTime:5.000] )
    {
        NSLog(@"Didn't get a ATS2=255\r\n reply\n");
        return NO;
    }
    if(! [self ask:@"AT&D0" valid:@"OK" invalid:@"ERROR" maximumTime:5.000] )
    {
        NSLog(@"Didn't get a ATD0 reply\n");
        return NO;
    }

    {
        int file;
        
        file=open("/dev/tty",O_RDWR);
        ioctl(file, TIOCNOTTY,0);
        close(file);
    }
    
    [port release];
    close(0);
    close(1);
    
    if(! (port=[[Port alloc] initWithDevice:[@"ttyd" stringByAppendingString:device]] ) )
    {
        NSLog(@"Can't open device ttyd%@\n",device);
        return NO;
    }
    [port unlock];

    if(! [self ask:@"AT&D1" valid:@"OK" invalid:@"ERROR" maximumTime:5.000] )
    {
        NSLog(@"Didn't get modem to hangup on carrier drop this is probaly fatal ! \n");
        return NO;
    }
    if(! [self ask:@"ATO" valid:@"CONNECT" invalid:@"ERROR" maximumTime:5.000] )
    {
        NSLog(@"Didn't get a Reconnect reply\n");
        return NO;
    }

    if([defaults integerForKey:@"DEBUG"])
        NSLog(@"Starting getty %@ %@\n",[defaults objectForKey:@"getty"],[defaults objectForKey:@"gettyarg"]);

    dup2([port fileDescriptor],0);
    dup2([port fileDescriptor],1);
    dup2([port fileDescriptor],2);

    {
        int i;
        thread_array_t thread_list;
        unsigned int thread_count;
        task_threads(task_self(),&thread_list,&thread_count);

        for(i=0;i<thread_count;i++)
        {
            if(thread_list[i]!=thread_self())
            {       
                thread_suspend(thread_list[i]);
                thread_abort(thread_list[i]);
                thread_terminate(thread_list[i]);
            }
        }
    }

    execle( [[defaults objectForKey:@"getty"] cString],
            [[defaults objectForKey:@"getty"] cString],
            [[defaults objectForKey:@"gettyarg"] cString],NULL,NULL);
    NSLog(@"Can't start getty %@\n", [defaults objectForKey:@"getty"]);
    return NO;
}




- port
{
    return port;
}

- (int) sendFax:(Fax *)fax
{
    return 0;
}

- (int) playVoice:(Voice *)voice
{
    return 0;
}


- (int) recordVoice:(Voice *)voice
{
    return 0;
}

@end
