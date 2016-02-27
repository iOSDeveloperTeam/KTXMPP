//
//  KTXMPPManager.m
//  ChatXMPP
//
//  Created by 周洪静 on 16/2/27.
//  Copyright © 2016年 KT. All rights reserved.
//

#import "KTXMPPManager.h"
//宏
#import "ChatXMPP_Header.h"
//xmpp
#import "XMPP.h"//Basis
#import "XMPPReconnect.h"//连接相关
#import "XMPPCapabilities.h"
#import "GCDAsyncSocket.h"
#import "XMPPMessage.h"//消息相关
@implementation KTXMPPManager
{
    NSUserDefaults * _userDefaults;
    NSString * _myPassword;//用户密码
    XMPPStream * _xmppStream;//xmpp主要流
    XMPPReconnect * _xmppReconnect;
    BOOL allowSelfSignedCertificates;
    BOOL allowSSLHostNameMismatch;
    
}
static KTXMPPManager * basisManager = nil;
+(KTXMPPManager *)defaultManager
{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        basisManager = [[KTXMPPManager alloc]init];
    });
    return basisManager;
}
-(instancetype)init
{
    if (self = [super init]) {
        [self setupStream];    }
    return self;
}
#pragma mark - 
#pragma mark - public
- (void)loginXMPP
{
    if (![_xmppStream isDisconnected])//如果xmpp未断开链接
    {
        return ;
    }
    //1.从userdefaults中提取账户和密码，所以在登录APP的时候需要记录用户的账户和密码
    //xmpp中Jid为我们俗称的账号ID
    NSString * myJid = [_userDefaults objectForKey:KT_XMPPJid];
    //密码
    NSString * myPassword = [_userDefaults objectForKey:KT_XMPPPassword];
    if (0 == myJid.length || 0 == myPassword.length) {
        UIAlertView * alertView = [[UIAlertView alloc]initWithTitle:@"警告" message:@"请检查是否输入了用户名或密码" delegate:self cancelButtonTitle:@"确定" otherButtonTitles: nil];
        [alertView show];
        return ;
    }
    //设置xmpp流的帐号，domain为主机名(非iP地址)，resource资源名：用于区分用户
    [_xmppStream setMyJID:[XMPPJID jidWithUser:myJid domain:KT_XMPPDomain resource:KT_XMPPResources]];
    _myPassword = myPassword;
    NSError *error = nil;
    //进行连接
    /*
     连接过程
     1.连接服务器 connectWithTimeout
     2.验证密码 authenticateWithPassword(成功或失败)
     */
    if (![_xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:&error]) {
        NSLog(@"连接错误");
        
        UIAlertView*al=[[UIAlertView alloc]initWithTitle:@"服务器连接失败" message:nil delegate:self cancelButtonTitle:@"ok" otherButtonTitles: nil];
        [al show];
        
        return ;
    }

}
#pragma mark - 
#pragma mark - 关于xmpp的初始化
//初始化设置xmppStream
-(void)setupStream
{
    NSAssert(_xmppStream == nil, @"Method setupStream invoked multiple times");
    _userDefaults = [NSUserDefaults standardUserDefaults];
    _xmppStream = [[XMPPStream alloc]init];
#if !TARGET_IPHONE_SIMULATOR
    {
        //是否允许后台连接
        _xmppStream.enableBackgroundingOnSocket = YES;
    }
#endif
    //自动重连 并激活
    _xmppReconnect = [[XMPPReconnect alloc]init];
    [_xmppReconnect activate:_xmppStream];
    //设置代理
    /*
     xmpp本身为串行队列，如果加到主队列中必然会造成性能的下降
     */
    [_xmppStream addDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
    // You may need to alter these settings depending on the server you're connecting to
    //您可能需要改变这些设置取决于您连接到的服务器
    allowSelfSignedCertificates = NO;
    allowSSLHostNameMismatch = NO;
    
    //TODO：消息模块的激活
}
#pragma mark -
#pragma mark - XMPPStreamDelegate
- (void)xmppStreamWillConnect:(XMPPStream *)sender
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}
- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    //验证密码
    NSError *error = nil;
    if (![_xmppStream authenticateWithPassword:_myPassword error:&error])
    {
        NSLog(@"Error authenticating: %@", error);
    }
}
//验证通过
- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    NSLog(@"完成认证，发送在线状态");
    //发送个人状态
    [self goOnline];
    
    if ([self.delegate respondsToSelector:@selector(loginXMPPRsult:)]) {
        [self.delegate loginXMPPRsult:YES];
    }
}
//验证错误
- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
    NSLog(@"认证错误");
    //断开连接
    [_xmppStream disconnect];
    if ([self.delegate respondsToSelector:@selector(loginXMPPRsult:)]) {
        [self.delegate loginXMPPRsult:NO];
    }
}
#pragma mark -
#pragma mark - 服务器交互
-(void)goOnline
{
    XMPPPresence *presence = [XMPPPresence presence];
    [_xmppStream sendElement:presence];
    NSLog(@"发送在线状态");
}

@end
