/*
    title   :   ModemServerProtocol.h
*/


#define     MODEM_ServerName        @"JollysModemServer"
#define     MODEM_ServerHost        @""
#define     MODEM_ClientName        @"JollysModemClient"
#define     MODEM_ClientHost        @""


@protocol ModemServerProtocol

-   dataOnLine:sender;               // gets called from our modem if we have something on the line

@end