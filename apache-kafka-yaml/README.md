1. set the node IP first `node-a.example` `node-b.example` `node-c.example` on selector
2. kubectl apply -f full.yaml

## install kafka-cli

```
sudo apt install -y default-jre
wget https://downloads.apache.org/kafka/4.1.1/kafka_2.13-4.1.1.tgz
tar -xvzf kafka_2.13-4.1.1.tgz
cd kafka_2.13-4.1.1
```

## test (inside pod)

```
admin@ip-172-31-40-76:~/kafka_2.13-4.1.1$ kubectl exec -it pod/broker-1-5b49cb8578-nkjhr -- bash
broker-1-5b49cb8578-nkjhr:/$ /opt/kafka/bin/kafka-topics.sh --bootstrap-server broker-1:9092 --list

broker-1-5b49cb8578-nkjhr:/$ /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server 43.218.112.23:9092 \
  --create \
  --topic my-topic \
  --partitions 3 \
  --replication-factor 3
Created topic my-topic.
broker-1-5b49cb8578-nkjhr:/$ /opt/kafka/bin/kafka-topics.sh --bootstrap-server broker-1:9092 --list
my-topic
```

## Caveats
1. Cannot hit from outside because advertised address is internal domain (broker-1, broker-2, etc). unknown from outside

Workaround

set /etc/hosts to match with internal domain (see proof/workaround.png)

```
# cat /etc/hosts | grep broker-
43.218.112.23 broker-1
16.78.84.239  broker-2
16.79.125.96  broker-3

# bin/kafka-topics.sh --bootstrap-server 43.218.112.23:9092 --list
my-topic
```

## cleanup

```
kubectl delete all --all -n kafka
```