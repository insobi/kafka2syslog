KAFKA_VERSION=2.8.0
SCALA_VERSION=2.13

sudo apt update
sudo apt install -y default-jre syslog-ng wget

# install zookeeper and kafka
wget https://mirror.navercorp.com/apache/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz
tar -xzf kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz 
rm -f kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz
ln -s kafka_${SCALA_VERSION}-${KAFKA_VERSION} kafka

# configure syslog-ng
sudo cp kafka_sender.conf /etc/syslog-ng/conf.d/
sudo systemctl restart syslog-ng
