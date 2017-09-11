#!/bin/bash

. ./kafka_env.sh
$kafka_dir/bin/kafka-run-class.sh kafka.tools.ImportZkOffsets --input-file zk_offsets.txt --zkconnect $zk_host:2181

