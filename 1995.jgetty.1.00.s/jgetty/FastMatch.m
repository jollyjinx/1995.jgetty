/*      FastMatch.m

        author  : jolly - who else ?
        version : 0.00
        date    : Tue Nov  1 19:05:42 MET 1994

*/


#import "FastMatch.h"

#import <string.h>

@implementation FastMatch

- init
{
    u_char  ci;
    
    [super init];

    string      =NULL;
    matchtable  =calloc(256,sizeof(u_char));
    matchlist   =calloc(256,sizeof(u_char*));
    waitinglist =calloc(256,sizeof(u_char));
    for(ci=0;ci<255;ci++)
        matchlist[ci]=calloc(256,sizeof(u_char));
    
    return self;
}



- freeStrings
{
    u_char ci;
    
    for(ci=0;ci<nstrings;ci++)
    {
        free(string[ci]);
        free(mstring[ci]);
    }
    free(string);
    free(mstring);
    free(lstring);
    free(cstring);

    return self;
}


-(void) dealloc
{
    u_char ci;
    
    for(ci=0;ci<255;ci++)
        free(matchlist[ci]);
    free(matchlist);
    free(matchtable);
    free(waitinglist);
    
    [self freeStrings];
    
    return [super dealloc];
}


- setMatchingStrings:(NSArray *)str
{
    NSEnumerator    *enumerator;
    NSString        *momString;
    u_char  ci,cj,mom;
    u_char  c;
    
    if(string) [self freeStrings];
    if(! (nstrings=[str count]) ) return nil;   
    
    string  =(u_char**)malloc(nstrings*sizeof(char*));
    mstring =(u_char**)malloc(nstrings*sizeof(u_char*));
    lstring =(u_char*)malloc(nstrings*sizeof(unsigned char));
    cstring =(u_char*)malloc(nstrings*sizeof(unsigned char));
    
    enumerator=[str objectEnumerator];
    mom=0;
    while( momString=[enumerator nextObject] )
    {
        lstring[mom]=[momString cStringLength];
        string[mom]=(u_char*)[momString cString];
        mstring[mom]=(u_char*)malloc(lstring[mom]+1);

        if(lstring[mom]>2)
        {
            cj=0;
            c=*string[mom];
            for(ci=1;ci<lstring[mom];ci++)
            {
                if( (string[mom])[ci]==c )
                {
                    (mstring[mom])[ci]=cj++;
                    c=(string[mom])[cj];
                }
                else
                {
                    (mstring[mom])[ci]=cj;
                    c=*string[mom];
                    cj=0;
                }
            }           
        }
        mom++;
    }
    
    return [self reset];
}






- reset
{
    u_char  ci;
    
    bzero(matchtable,256);
    bzero(cstring,nstrings);
    for(ci=0;ci<nstrings;ci++)
    {
        matchlist[ *string[ci] ][ matchtable[ *string[ci] ]++ ]=ci;
    }
    waiting=0;

    return self;
}

#define REMOVE_FROM_MATCHTABLE(C,STRNR)     {                                                                   \
                                                u_char  mtv;                                                    \
                                                                                                                \
                                                for(mtv=0; mtv<matchtable[C]; mtv++)                            \
                                                {                                                               \
                                                    if( matchlist[C][mtv]==STRNR )                              \
                                                    {                                                           \
                                                        matchlist[C][mtv]=matchlist[C][--matchtable[C]];        \
                                                        break;                                                  \
                                                    }                                                           \
                                                }                                                               \
                                            }

#define ADD_TO_MATCHTABLE(C,STRNR)          {                                                                   \
                                                matchlist[C][matchtable[C]++]=STRNR;                            \
                                            }

-(int) matchWithBuffer:(u_char *)buffer size:(int)size
{
    matchbegin=buffer;
    matchend=buffer+size;
    
    return [self match];
}


- (int) match
{
    u_char  c;
    u_char  ci;
    u_char  matched=255;
    u_char  stringnumber,waitchar;
    u_char  newwaiting;
    
    u_char  *scanbegin=matchbegin;
    
    if(!string) return -2;
    if(matchbegin==matchend) return -2;
    
    while( matchbegin<matchend )
    {
        if( matchtable[c=*matchbegin++] )
        {
            newwaiting=0;
            for(ci=0;ci<waiting;ci++)
            {
                stringnumber=waitinglist[ci];
                waitchar=string[stringnumber][cstring[stringnumber]];
                if(waitchar==c)
                {
                    REMOVE_FROM_MATCHTABLE(c,stringnumber)
                    
                    if(lstring[stringnumber]==++cstring[stringnumber])
                    {
                        cstring[stringnumber]=0;
                        matched=stringnumber;
                    }
                    else
                        waitinglist[newwaiting++]=stringnumber;
                }
                else
                {
                    REMOVE_FROM_MATCHTABLE(string[stringnumber][cstring[stringnumber]],stringnumber)
                    do
                    {
                        cstring[stringnumber]=mstring[stringnumber][cstring[stringnumber]];
                    }
                    while( cstring[stringnumber] && c!=(string[stringnumber])[cstring[stringnumber]] );

                    if( c==string[stringnumber][cstring[stringnumber]] )
                    {
                        cstring[stringnumber]++;
                        waitinglist[newwaiting++]=stringnumber;
                    }
                }
                waitchar=string[stringnumber][cstring[stringnumber]];
                ADD_TO_MATCHTABLE(waitchar,stringnumber)
            }
            waiting=newwaiting;
            
            for(ci=0;ci<matchtable[c];ci++)
            {
                stringnumber=matchlist[c][ci];
                if( cstring[stringnumber]++ == 0 )
                {
                    if(lstring[stringnumber]==1)
                    {
                        cstring[stringnumber]=0;
                        matched=stringnumber;
                    }
                    else
                    {
                        waitchar=string[stringnumber][1];
                        if(waitchar!=c)
                        {
                            REMOVE_FROM_MATCHTABLE(c,stringnumber)
                            ADD_TO_MATCHTABLE(waitchar,stringnumber)
                            ci--;
                        }
                        waitinglist[waiting++]=stringnumber;
                    }
                }
                else
                    cstring[stringnumber]--;
            }
            
        }
        else
        {
            newwaiting=0;
            for(ci=0;ci<waiting;ci++)
            {
                stringnumber=waitinglist[ci];
                waitchar=string[stringnumber][cstring[stringnumber]];
                if(matchtable[waitchar]==1)
                    matchtable[waitchar]=0;
                else
                    REMOVE_FROM_MATCHTABLE(waitchar,stringnumber)

                do
                {
                    cstring[stringnumber]=mstring[stringnumber][cstring[stringnumber]];
                }
                while( cstring[stringnumber] && c!=string[stringnumber][cstring[stringnumber]] );
                
                if(c==string[stringnumber][cstring[stringnumber]])
                {
                    cstring[stringnumber]++;
                    waitinglist[newwaiting++]=stringnumber;
                }
                waitchar=string[stringnumber][cstring[stringnumber]];
                ADD_TO_MATCHTABLE(waitchar,stringnumber)
                
            }
            waiting=newwaiting;
        }
        
        if(matched!=255)
        {
            return ((matchbegin-scanbegin)<<8 | (int)matched);
        }
    }
    return -1;  // no match
}






@end


