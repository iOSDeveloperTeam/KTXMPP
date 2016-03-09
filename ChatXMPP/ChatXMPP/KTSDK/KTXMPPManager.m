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
    BOOL isRegister;//是否为注册
    
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
//连接
- (BOOL)connect
{
    if (![_xmppStream isDisconnected])//如果xmpp未断开链接
    {
        return YES;
    }
    //1.从userdefaults中提取账户和密码，所以在登录APP的时候需要记录用户的账户和密码
    //xmpp中Jid为我们俗称的账号ID
    NSString * myJid = [_userDefaults objectForKey:KT_XMPPJid];
    //密码
    NSString * myPassword = [_userDefaults objectForKey:KT_XMPPPassword];
    if (0 == myJid.length || 0 == myPassword.length) {
        UIAlertView * alertView = [[UIAlertView alloc]initWithTitle:@"警告" message:@"请检查是否输入了用户名或密码" delegate:self cancelButtonTitle:@"确定" otherButtonTitles: nil];
        [alertView show];
        return NO;
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
        
        return NO;
    }
    return YES;
}
//登录
- (void)loginXMPP
{
    isRegister = NO;
    //先 连接服务器 再 认证用户米密码
    [self connect];
}
//注册
-(void)registerXMPP
{
/*
    注册和登录的相同之处:两者都需要连接服务器
            的不同之处:登录在连接成功后验证密码，而注册为注册用户
 */
    isRegister = YES;
    //先 连接服务器 再 注册用户密码
    [self connect];
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
    
    
    [_xmppStream setHostName:KT_XMPPIP];//设置主机IP
    [_xmppStream setHostPort:KT_XMPPPort];//设置主机端口
    
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
    if (isRegister) {
        //注册
        if (![_xmppStream registerWithPassword:_myPassword error:&error]) {
            NSLog(@"Error register: %@",error);
        }
    }else{
        //登录
        if (![_xmppStream authenticateWithPassword:_myPassword error:&error])
        {
            NSLog(@"Error authenticating: %@", error);
        }

    }
}
//登录验证通过
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
//登录验证错误
- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
    NSLog(@"认证错误");
    //断开连接
    [_xmppStream disconnect];
    if ([self.delegate respondsToSelector:@selector(loginXMPPRsult:)]) {
        [self.delegate loginXMPPRsult:NO];
    }
}
//注册成功
- (void)xmppStreamDidRegister:(XMPPStream *)sender
{
    if ([self.delegate respondsToSelector:@selector(registerXMPPRsult:)]) {
        [self.delegate registerXMPPRsult:YES];
    }
}
//注册失败
- (void)xmppStream:(XMPPStream *)sender didNotRegister:(DDXMLElement *)error
{
    NSLog(@"Error didNotRegister %@",error);
    if ([self.delegate respondsToSelector:@selector(registerXMPPRsult:)]) {
        [self.delegate registerXMPPRsult:NO];
    }
}
#pragma mark -
#pragma mark - 单点登录
/*
    xmpp的原理为：登陆账号(JID)的资源名重复，当两个 相同资源名 的 相同账号 同时登陆时，调用此方法；
    如：A端： 帐号@openfire.com/ios  其中ios为资源名
        B端： 帐号@openfire.com/ios  其中ios为资源名
        此时会调用此方法，
        xmpp服务器会将新消息发送给后登陆服务器的客户端，如果同一帐号的资源名不相同，则不会掉用词方法，两个帐号会同时在线，发送消息时，指定接受消息的帐号的资源名，会根据资源名指定推送，如果不加人资源名，则随机发送
 */
- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
    NSLog(@"登陆冲突=====:%@",error);
    DDXMLNode *errorNode = (DDXMLNode *)error;
    //遍历错误节点
    for(DDXMLNode *node in [errorNode children]){
        //若错误节点有【冲突】
        if([[node name] isEqualToString:@"conflict"]){
            [self disconnect];
            //程序运行在后台，发送本地通知
            if ([[UIApplication sharedApplication] applicationState] !=UIApplicationStateActive) {
                UILocalNotification *localNotification = [[UILocalNotification alloc] init];
                localNotification.alertAction = @"确定";
                localNotification.alertBody = [NSString stringWithFormat:@"你的账号已在其他地方登录，本地已经下线。"];//通知主体
                
                [localNotification setSoundName:UILocalNotificationDefaultSoundName]; //通知声音
                
                [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];//发送通知
                
            }
            //回调方法
            if ([self.delegate respondsToSelector:@selector(aloneLoginXMPP)]) {
                [self.delegate aloneLoginXMPP];
            }
        }
    }
}
//离线方法
- (void)disconnect
{
    //发送离线消息
    [self goOffline];
    [_xmppStream disconnect];
    //停止重连
    [_xmppReconnect setAutoReconnect:NO];
}
//发送离线状态
- (void)goOffline
{
    XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
    
    [_xmppStream sendElement:presence];
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
