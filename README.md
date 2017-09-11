# A little demo showing how to pull data into Greenplum DB (GPDB) from a Kafka topic, then push data back out into Kafka

## The simplest way to run this is to have GPDB and Kafka running on the same machine, so let's go over that.

1. Log into a GPDB Single Node VM as user "gpadmin"
1. Place a copy of this repo into `~gpadmin/`
1. Create a database, "gpadmin", if it doesn't already exist

### Set up Kafka
1. Download and install the latest Apache Kafka release, per the [Quick Start](https://kafka.apache.org/quickstart)
1. Edit `kafka_env.sh` to suit your deployment:
   ```
   # Set up environment, shared across scripts
   export kafka_dir="$HOME/kafka_2.11-0.11.0.0"
   export zk_host=localhost
   export KAFKA_HEAP_OPTS="-Xmx16G -Xms16G"
   ```
1. `cd $HOME/gpdb-kafka-round-trip/` 
1. Start up Zookeeper: `./zk_start.sh`, and check `./zk.log` to ensure that was successful (also, note this log file can get large).
1. Start up Kafka: `./kafka_start.sh`.  Again, verify it's running by checking `./kafka.log`.
1. Create a topic, `chicago_crimes`: `./kafka_create_topic.sh`

### Prepare the Go Kafka client programs
1. Follow [this procedure](https://github.com/mgoddard-pivotal/confluent-kafka-go#installing-librdkafka) to install the underlying C Kafka client library.  The two Go programs are dynamically linked to this library, so it will need to be installed onto each of the segment hosts in your GPDB cluster (on the Single Node VM, you just install it in one place).
1. If there is a pre-compiled binary for your platform in [./bin](./bin), you can just symlink each of them into `$HOME/` and skip the remainder of this section.
1. Install Go, per [these instructions](https://golang.org/doc/install).
1. Refer to [this link](https://github.com/mgoddard-pivotal/confluent-kafka-go#install-the-client) for guidance on installing the Go Kafka client.
1. `git clone https://github.com/mgoddard-pivotal/confluent-kafka-go.git`
1. `cd ./confluent-kafka-go/examples/`
1. In the Bash shell, this should produce executables of the required binaries, placing them into `$HOME`:
   ```
   for dir in go-kafkacat producer_example
   do
     cd $dir
     go build . && cp ./$dir ~/
     cd -
   done
   ```

### Run the demo
1. `cd $HOME/gpdb-kafka-round-trip/`
1. Run `./kafka_gpdb_kafka_roundtrip_demo.sh`, and hit "enter" at each prompt.


