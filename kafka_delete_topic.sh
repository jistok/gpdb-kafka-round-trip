#!/bin/bash

if [ "$#" -ne 1 ]
then
  echo "Usage: $0 topic_name"
  exit 1
fi

topic=$1

. ./kafka_env.sh
$kafka_dir/bin/kafka-topics.sh --delete --topic $topic --zookeeper $zk_host:2181

