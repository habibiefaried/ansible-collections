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
  --bootstrap-server localhost:9092 \
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

```
admin@ip-172-31-40-76:~/kafka_2.13-4.1.1$ kubectl logs pod/broker-3-54d8c85b69-jpl88 | grep advertised
        advertised.listeners = PLAINTEXT://broker-3:19092,PLAINTEXT_HOST://broker-3:9092
        advertised.listeners = PLAINTEXT://broker-3:19092,PLAINTEXT_HOST://broker-3:9092
```

need to edit yaml so it will go to real IP and port running