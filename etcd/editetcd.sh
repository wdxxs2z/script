#!/bin/bash

function editetcd() {

echo "#!/bin/bash

RUN_DIR=/var/vcap/sys/run/etcd
PIDFILE=\$RUN_DIR/etcd.pid
WORK_DIR=/var/vcap/store/etcd
JOB_DIR=/var/vcap/jobs/etcd

source /var/vcap/packages/common/utils.sh

case \$1 in

  start)
    pid_guard \$PIDFILE \"etcd\"

    mkdir -p \$RUN_DIR
    mkdir -p \$WORK_DIR

    chown -R vcap:vcap \$RUN_DIR
    chown -R vcap:vcap \$WORK_DIR

    /var/vcap/packages/syslog_aggregator/setup_syslog_forwarder.sh \$JOB_DIR/config

    echo \$\$ > \$PIDFILE

    

    exec chpst -u vcap:vcap /var/vcap/packages/etcd/etcd -snapshot -data-dir=\$WORK_DIR \\
        -addr=$1:4001 \\
        -peer-addr=$1:7001 \\
        -name=micro_ng-$2 \\
        $3\\
        \\
        -peer-heartbeat-timeout=50 \\
        -peer-election-timeout=1000
    ;;

  stop)
    kill_and_wait \$PIDFILE

    ;;

  *)
    echo \"Usage: etcd_ctl {start|stop}\"

    ;;

esac
" >> /var/vcap/jobs/etcd/bin/etcd_ctl
}

etcd="$1"
index="$2"
peers="$3"

editetcd "$1" "$2" "$3"
