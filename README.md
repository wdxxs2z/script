cf-auto-deployment
==================

This is a auto deployment script to install cloudfoundry v2.0 v173

1.First you must make sure that your cf env is clean.And you will make a user:"vcap"
sudo useradd -m vcap

2.Second install etcdstore and start etcd make the deployment env
deployment.etcd is deployment clusters,we must make the etcd connect correct.

3.Modify and write your manifest
manifest is important file:zone,domain,etcdcluster(not deployment).

4.In accordance with the deployment installation order form.
install manifest2etcd.sh
install postgresql
install gnatsd
install uaa
install loggregator
install loggregator_traffic
install dea_logging_agent
install nginx
install cloud_controller_ng
install cloud_controller_worker
install cloud_controller_clock
install dea_next
install hm9000
install gorouter
install haproxy
