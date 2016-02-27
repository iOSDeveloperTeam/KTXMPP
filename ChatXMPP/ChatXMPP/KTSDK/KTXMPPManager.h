//
//  KTXMPPManager.h
//  ChatXMPP
//
//  Created by 周洪静 on 16/2/27.
//  Copyright © 2016年 KT. All rights reserved.
//

#import <Foundation/Foundation.h>
/*
 *********************写在前边*************************
    旨在大家共同学习xmpp的关于IM的基本方法，暂定包括：登陆注册，单聊群聊，单点登录
    写前废话：在网上看了看环信即时通讯SDK，它的模式和xmpp基本相同，根据xmpp的一些经验，好友功能并不好用，遂环信中也不推荐使用，环信中包括单聊，群聊和聊天室，这正是xmpp的使用特点，单聊不必多说，群聊和聊天室，个人认为分别对应的是 
            xmpp广播->环信群聊
            xmpp群聊->环信聊天室(xmpp所谓的群聊就是聊天室的形式，其中的人员并不能长期存储其中)
    使用前:导入XMPP中的所有文件
          导入库libresolv.tbd
          导入CFNetwork.framework
          导入Security.framework
          导入libxml.tbd 在header Search Paths中设置$(SDKROOT)/usr/include/libxml2(xmpp本身就是xml格式)
          xmpp需要有后台服务器配合，本次以openfire服务器为例，需要搭建，如没有后台朋友有帮助，可自行百度教程创建
 */
@protocol KTXMPPManagerDelegate <NSObject>
//登陆xmpp的结果
- (void)loginXMPPRsult:(BOOL)ret;


@end
@interface KTXMPPManager : NSObject
@property (nonatomic,weak)id<KTXMPPManagerDelegate>delegate;

//单例
+ (KTXMPPManager *)defaultManager;
@end

