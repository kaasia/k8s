#!/bin/bash
#--------------------------------------------
#用于实现集群环境的自动部署脚本
#author: wang_yzhou
#date: 20170726
#说明：适用于centos7系统
#--------------------------------------------
echo "开始进行集群的安装"
sleep 5
echo "3秒后开始安装......"
sleep 3
#判断当前用户是否为root用户
user=`whoami`
machinename=`uname -m`
if [ "$user" != "root" ]; then
    echo "请在root下执行该脚本"
    exit 1
fi

#更换阿里云源
change_aliyum(){
#检测wget命令是否安装
command -v wget >/dev/null 2>&1 || { echo >&2 "I require wget but it's not installed.  trying to get wget."; yum install -y wget; }
#更换阿里云源
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum makecache
}

#关闭防火墙
close_firewall(){
systemctl stop firewalld
systemctl disable firewalld
}
#安装master组件
install_master_module(){
echo "请确定当前机器没有安装docker,etcd,kubernetes"
read -p "input (y/n):" yn
[ "$yn" == "Y" ] || [ "$yn" == "y" ]&& echo "ok,continue"&& yum install -y etcd docker kubernetes
[ "$yn" == "N" ] || [ "$yn" == "n" ]&& echo "请先完成干净卸载后，再运行本脚本" && exit 1
}

#修改etcd配置文件
update_etcd_conf(){
echo "ETCD_NAME=default
ETCD_DATA_DIR=\"/var/lib/etcd/default.etcd\"
ETCD_LISTEN_CLIENT_URLS=\"http://0.0.0.0:2379\"
ETCD_ADVERTISE_CLIENT_URLS=\"http://localhost:2379\"">/etc/etcd/etcd.conf
}

#修改apiserver配置文件
update_apiserver_conf(){
echo "KUBE_API_ADDRESS=\"--address=0.0.0.0\"
KUBE_API_PORT=\"--port=8080\"
KUBELET_PORT=\"--kubelet_port=10250\"
KUBE_ETCD_SERVERS=\"--etcd_servers=http://127.0.0.1:2379\"
KUBE_SERVICE_ADDRESSES=\"--service-cluster-ip-range=10.254.0.0/16\"
KUBE_ADMISSION_CONTROL=\"--admission_control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ResourceQuota\"
KUBE_API_ARGS=\"\"">/etc/kubernetes/apiserver
}

#修改kubernetes配置文件
update_kube_conf(){
read -p "输入master节点的ip地址:" ip
echo "KUBE_LOGTOSTDERR=\"--logtostderr=true\"
KUBE_LOG_LEVEL=\"--v=0\"
KUBE_ALLOW_PRIV=\"--allow-privileged=false\"
KUBE_MASTER=\"--master=http://$ip:8080\"">/etc/kubernetes/config
}

#启动master节点的相关服务
up_master_service(){
for SERVICES  in etcd docker kube-apiserver kube-controller-manager kube-scheduler;  do
    systemctl restart $SERVICES
    systemctl enable $SERVICES
    systemctl status $SERVICES -l
done
}

#添加etcd网络配置
add_etcd_net(){
etcdctl mk /atomic.io/network/config '{"Network":"172.17.0.0/16"}'
}

#检测集群是否安装成功
check_cluster_status(){
kubectl get nodes
}

#安装node节点组件
install_node_module(){
echo "请确定当前机器没有安装flannel,docker,kubernetes"
read -p "input (y/n):" yn
[ "$yn" == "Y" ] || [ "$yn" == "y" ]&& echo "ok,continue"&& yum install -y flannel docker kubernetes
[ "$yn" == "N" ] || [ "$yn" == "n" ]&& echo "请先完成干净卸载后，再运行本脚本" && exit 1
}

#配置flanneld
update_flanneld_conf(){
read -p "输入master节点的ip地址:" ip
echo "FLANNEL_ETCD=\"http://$ip:2379\"
FLANNEL_ETCD_ENDPOINTS=\"http://$ip:2379\"
FLANNEL_ETCD_PREFIX=\"/atomic.io/network\"">/etc/sysconfig/flanneld
}

#配置kubelet
update_kubelet_conf(){
read -p "输入master节点的ip地址：" master
read -p "输入当前node节点的ip地址：" node
read -p "输入pause镜像的仓库地址：" image
echo "KUBELET_ADDRESS=\"--address=0.0.0.0\"
KUBELET_PORT=\"--port=10250\"
KUBELET_HOSTNAME=\"--hostname-override=$node\"
KUBELET_API_SERVER=\"--api-servers=http://$master:8080\"
KUBELET_POD_INFRA_CONTAINER=\"--pod-infra-container-image=$image\"
KUBELET_ARGS=\"--cluster-dns=10.254.0.100 --cluster-domain=cluster.local\"">/etc/kubernetes/kubelet
}

#启动node节点相关服务
up_node_service(){
for SERVICES in kube-proxy kubelet docker flanneld; do
    systemctl restart $SERVICES
    systemctl enable $SERVICES
    systemctl status $SERVICES 
done
}

#脚本入口
echo -n "选择要安装的角色“master”，“node”(严格大小写)："
read answer
if [ "$answer" == master ];then
  
  change_aliyum
  close_firewall
  install_master_module
  update_etcd_conf
  update_apiserver_conf
  update_kube_conf
  up_master_service
  add_etcd_net

elif [ "$answer" == node ];then

  change_aliyum
  close_firewall
  install_node_module
  update_flanneld_conf
  update_kube_conf
  update_kubelet_conf
  up_node_service

fi


