#!/bin/bash
#--------------------------------------------
#将指定war包打成指定名称的tomcat6版本的镜像
#author:wang_yazhou
#date: 20170802
#说明：适用于centos7系统
#--------------------------------------------
read -p "输入war包名称(全名，如不在当前目录需要指定路径):" war
read -p "输入要打成的镜像名称(name:version):" image
echo "From hub.c.163.com/library/tomcat:6.0.45
ADD $war /usr/local/tomcat/webapps/
#设置时区
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo 'Asia/Shanghai' >/etc/timezone">Dockerfile
docker build -t $image .
