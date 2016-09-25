fluent-plugin-websphere-iib
===========================

fluentd plugin for parsing IBM websphere IIB logs inthe syslog /var/log/messages

#Available format Plugins:
* websphere_iib_syslog: format logs in /var/log/messages for IBM websphere IIB
* websphere_iib_stdout: format logs in stdout for IBM websphere IIB

#Plugin Settings:
Both plugins have the same configuration options:

* remote_syslog: fqdn or ip of the remote syslog instance
* port: the port, where the remote syslog instance is listening
* hostname: hostname to be set for syslog messages
* remove_tag_prefix: remove tag prefix for tag placeholder. 
* tag_key: use the field specified in tag_key from record to set the syslog key
* facility: Syslog log facility
* severity: Syslog log severity
* use_record: Use severity and facility from record if available
* payload_key: Use the field specified in payload_key from record to set payload

#Configuration example:
```
<match site.*>
  type syslog_buffered
  remote_syslog your.syslog.host
  port 25
  hostname ${hostname}
  facility local0
  severity debug
</match>
```


Contributors:

* Victor Guillen
* [superguillen](http://github.com/superguillen)
