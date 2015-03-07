default['beaver']['basedir'] = '/opt/beaver'
default['beaver']['user'] = 'beaver'
default['beaver']['group'] = 'beaver'
default['beaver']['join_groups'] = []
default['beaver']['log_dir'] = '/var/log/beaver'
default['beaver']['pid_dir'] = '/var/run/beaver'
default['beaver']['sincedb_path'] = '/var/log/beaver/sincedb.sqlite'
default['beaver']['pip_package'] = 'beaver==33.1.0'
default['beaver']['format'] = 'raw'
default['beaver']['logrotate']['options'] = %w(missingok notifempty compress copytruncate)
default['beaver']['logrotate']['postrotate'] = 'invoke-rc.d beaver force-reload >/dev/null 2>&1 || true'
default['beaver']['logrotate']['days'] = 30
default['beaver']['sqs_aws_region'] = 'us-east-1'
default['beaver']['sqs_aws_queue'] = 'logstash-input'
default['beaver']['sqs_aws_access_key'] = ''
default['beaver']['sqs_aws_secret_key'] = ''

include_attribute "beaver::customize"
