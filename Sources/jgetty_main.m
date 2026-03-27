/*	TEXT WAS MADE WITH 4*SPACE = 1*TAB

	program	:	main.c
	version	:	see the version.h file	
	date	:	Sat Oct  7 16:11:57 MET 1995
	purpose	:	main for do modem 
	author	:	by jolly ( who else )

*/
#import <Foundation/Foundation.h>
#import <libc.h>
#import "Modem.h"


int main(int argc,char *argv[])
{
    NSString *ttyName;
    NSUserDefaults *defaults;
    NSMutableDictionary	*dict;

    NSAutoreleasePool *neverReleasedPool = [[NSAutoreleasePool alloc] init];
    dict=[NSMutableDictionary dictionaryWithCapacity:20];
    [dict setObject:@"0"			forKey:@"DEBUG"];
    [dict setObject:@"/dev/console"		forKey:@"Logfile"];

    [[NSProcessInfo processInfo] setProcessName:@"JollysFax"];
    defaults=[NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:dict];

    close(0);
    close(1);
    close(2);

    dup2(open([[defaults stringForKey:@"Logfile"] cString],O_WRONLY|O_APPEND),2);
    close(0);


    if( !isatty(0) )
    {
        if(argc==2)
        {
            ttyName=[@"/dev/" stringByAppendingString:[NSString stringWithCString:argv[1]]];
        }
        else
        {
            NSLog(@"Fatal error, can't determine device I'm connected to.\n");
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:5.000]];
            return EXIT_FAILURE;
        }
    }
    else
    {
        ttyName=[[NSString alloc] initWithCString:ttyname(0)];
    }


    if([defaults integerForKey:@"DEBUG"]) NSLog(@"Using tty:%@\n",ttyName);


    while(1)
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        Modem *modemObject;

        if( ! (modemObject = [[Modem alloc] initWithDevice:ttyName]) )
        {
            NSLog(@"Can't create Modem object with device :%@\n",ttyName);
            return EXIT_FAILURE;
        }
        if([defaults integerForKey:@"DEBUG"]) NSLog(@"resetting Modem\n");
        if(YES == [modemObject reset])
        {
            [modemObject waitOnLine];
        }
        else
        {
            NSLog(@"Can't reset the modem \n");
            return EXIT_FAILURE;
        }
        [pool release];
    }

    [neverReleasedPool release]; // never reached
    return EXIT_FAILURE;
}




