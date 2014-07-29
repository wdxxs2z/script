cf-auto-deployment
==================
<p>
	<strong>This is a auto deployment script to install cloudfoundry v2.0 v173</strong><br />
<br />
1.First you must make sure that your cf env is clean<span style="line-height:1.5;">.And you will make a user:"vcap"</span>
</p>
<p>
	<br />
sudo useradd -m vcap<br />
<br />
<br />
2.Second install etcdstore and start etcd make the deployment env<br />
<br />
deployment.etcd is deployment clusters,we must make the etcd connect correct.<br />
<br />
3.Modify and write your manifest<br />
<br />
manifest is important file:zone,domain,etcdcluster(not deployment).<br />
<br />
4.In accordance with the deployment installation order form.<br />
<br />
install manifest2etcd.sh<br />
install postgresql<br />
install gnatsd<br />
install uaa<br />
install loggregator<br />
install loggregator_traffic<br />
install dea_logging_agent<br />
install nginx<br />
install cloud_controller_ng<br />
install cloud_controller_worker<br />
install cloud_controller_clock<br />
install dea_next<br />
install hm9000<br />
install gorouter<br />
install haproxy<br />
</p>
