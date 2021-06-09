# How to deploy

Deploy 2 VMs for Kafka and remote syslog-ng on Azure using terraform. This required installation of Azure CLI on your test environment.

```
az login
terraform init
terraform apply
```

It takes a few minutes to complete setting up kafka and syslog-ng after vm provisioning completed. After finished provisioning, edit /etc/syslog-ng/conf.d/kafka.conf on Kafka VM. Replace 'REMOTE_SYSLOG_IP' and 'REMOTE_SYSLOG_PORT' to proper values related second VM.
```
#udp(ip(REMOTE_SYSLOG_IP) port(REMOTE_SYSLOG_PORT));
```
then, restart syslog-ng on Kafka VM.