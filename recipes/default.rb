#
# Cookbook Name:: opsworks-beaver
# Recipe:: default
#
include_recipe "python::default"
include_recipe "logrotate"

package 'git'

group node['beaver']['group'] do
  system true
end

user node['beaver']['user'] do
  group node['beaver']['group']
  home "/var/lib/beaver"
  system true
  action :create
  manage_home true
end

directory node['beaver']['basedir'] do
  action :create
  owner "root"
  group "root"
  mode "0755"
end

node['beaver']['join_groups'].each do |grp|
  group grp do
    members node['beaver']['user']
    action :modify
    append true
    only_if "grep -q '^#{grp}:' /etc/group"
  end
end


basedir = node['beaver']['basedir']

conf_file = "#{basedir}/etc/beaver.conf"
log_file = "#{node['beaver']['log_dir']}/beaver.log"
pid_file = "#{node['beaver']['pid_dir']}/beaver.pid"
format = "#{node['beaver']['format']}"

[
  File.dirname(conf_file),
  File.dirname(log_file),
  File.dirname(pid_file),
].each do |dir|
  directory dir do
    owner node['beaver']['user']
    group node['beaver']['group']
    recursive true
    not_if do ::File.exists?(dir) end
  end
end

[ log_file, pid_file ].each do |f|
  file f do
    action :touch
    owner node['beaver']['user']
    group node['beaver']['group']
    mode '0640'
  end
end

python_pip node['beaver']['pip_package'] do
  action :install
end

# inputs
files = []
node['beaver']['inputs'].each do |ins|
  ins.each do |name, hash|
    case name
    when "file" then
      if hash.has_key?('path')
        files << hash
      else
        log("input file has no path.") { level :warn }
      end
    else
      log("input type not supported: #{name}") { level :warn }
    end
  end
end

# outputs
outputs = []
conf = {}
conf['logstash_version'] = 1
conf['sincedb_path'] = node['beaver']['sincedb_path']
node['beaver']['outputs'].each do |outs|
  outs.each do |name, hash|
    case name
    when "sqs" then
      outputs << "sqs"
      conf['sqs_aws_region'] = node['beaver']['sqs_aws_region']
      conf['sqs_aws_queue'] = node['beaver']['sqs_aws_queue']
      conf['sqs_aws_access_key'] = node['beaver']['sqs_aws_access_key']
      conf['sqs_aws_secret_key'] = node['beaver']['sqs_aws_secret_key']
    else
      log("output type not supported: #{name}") { level :warn }
    end
  end
end

output = outputs[0]
if outputs.length > 1
  log("multiple outputs detected, will consider only the first: #{output}") { level :warn }
end

cmd = "beaver -t #{output} -c #{conf_file} -F #{format}"

template conf_file do
  source 'beaver.conf.erb'
  mode 0640
  owner node['beaver']['user']
  group node['beaver']['group']
  variables(
    :conf => conf,
    :files => files
  )
  notifies :restart, "service[beaver]"
end

# use upstart when supported to get nice things like automatic respawns
use_upstart = false
supports_setuid = false
case node['platform_family']
when 'rhel'
  use_upstart = true if node['platform_version'].to_i >= 6
when 'fedora'
  use_upstart = true if node['platform_version'].to_i >= 9
when 'debian'
  use_upstart = true
  supports_setuid = true if node['platform_version'].to_f >= 12.04
end

if use_upstart
  template '/etc/init/beaver.conf' do
    mode '0644'
    source 'beaver-upstart-conf.erb'
    variables(
      cmd: cmd,
      group: node['beaver']['group'],
      user: node['beaver']['user'],
      log: log_file,
      supports_setuid: supports_setuid
    )
    notifies :restart, 'service[beaver]'
  end

  service 'beaver' do
    supports restart: true, reload: false
    action [:enable, :start]
    provider Chef::Provider::Service::Upstart
  end
else
  template '/etc/init.d/beaver' do
    mode '0755'
    source 'init-beaver.erb'
    variables(
      cmd: cmd,
      pid_file: pid_file,
      user: node['beaver']['user'],
      log: log_file,
      platform: node['platform']
    )
    notifies :restart, 'service[beaver]'
  end

  service 'beaver' do
    supports restart: true, reload: false, status: true
    action [:enable, :start]
  end
end

logrotate_app 'beaver' do
  cookbook 'logrotate'
  path log_file
  frequency 'daily'
  postrotate node['beaver']['logrotate']['postrotate']
  options node['beaver']['logrotate']['options']
  rotate node['beaver']['logrotate']['days'].to_i
  create "0640 #{node['beaver']['user']} #{node['beaver']['group']}"
end
