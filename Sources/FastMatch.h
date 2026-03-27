

#import <Foundation/Foundation.h>
#import <sys/types.h>

@interface FastMatch:NSObject
{
    u_char  nstrings;
    u_char  **string;               // strings to be matched
    u_char  *lstring;               // stringlength
    u_char  **mstring;              // pointer to next lower match ( in words like : "blablafasel" )
    u_char  *cstring;               // actual stringmatchcount
    
    u_char  *matchtable;            // table of all possible first case matches
    u_char  **matchlist;
    u_char  waiting;
    u_char  *waitinglist;
    u_char  *matchbegin;
    u_char  *matchend;
}


-       init;
-       freeStrings;
-(void) dealloc;

-       setMatchingStrings:(NSArray *)str;

-       reset;
- (int) matchWithBuffer:(u_char *)buffer size:(int)size;
- (int) match;

@end
