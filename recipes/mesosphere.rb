#
# Cookbook Name:: mesos
# Recipe:: mesosphere
#
# Copyright 2013, Shingo Omura
#
# All rights reserved - Do Not Redistribute
#
version = node[:mesos][:version]
download_url = "http://downloads.mesosphere.io/master/#{node['platform']}/#{node['platform_version']}/mesos_#{version}_amd64.deb"

# TODO(everpeace) platform_version validation
if !platform?("ubuntu") then
  Chef::Application.fatal!("#{platform} is not supported on #{cookbook_name} cookbook")
end

installed = File.exist?("/usr/local/sbin/mesos-master")
if installed then
  Chef::Log.info("Mesos is already installed!! Instllation will be skipped.")
end

# install dependencies and unzip
['unzip', 'libcurl3'].each do |pkg|
  package pkg do
    action :install
    not_if { installed == true }
  end
end

apt_package "default-jre-headless" do
  action :install
  not_if { installed==true }
end

# workaround for "error while loading shared libraries: libjvm.so: cannot open shared object file: No such file or directory"
link "/usr/lib/libjvm.so" do
  to "/usr/lib/jvm/default-java/jre/lib/amd64/server/libjvm.so"
  not_if "test -L /usr/lib/libjvm.so"
end

if node['mesos']['mesosphere']['with_zookeeper'] then
  ['zookeeper', 'zookeeperd', 'zookeeper-bin'].each do |zk|
    package zk do
      action :install
    end
   end
   service "zookeeper" do
      provider Chef::Provider::Service::Upstart
      action :restart
   end
 end

remote_file "#{Chef::Config[:file_cache_path]}/mesos_#{version}.deb" do
  source "#{download_url}"
  mode   0644
  not_if { installed==true }
  notifies :install, "dpkg_package[mesos]"
end

dpkg_package "mesos" do
  source "#{Chef::Config[:file_cache_path]}/mesos_#{version}.deb"
  action :install
  not_if { installed==true }
end

# configuration files for upstart scripts by build_from_source installation
template "/etc/init/mesos-master.conf" do
  source "upstart.conf.for.mesosphere.erb"
  variables(:init_state => "stop", :role => "master")
  mode 0644
  owner "root"
  group "root"
end

template "/etc/init/mesos-slave.conf" do
  source "upstart.conf.for.mesosphere.erb"
  variables(:init_state => "stop", :role => "slave")
  mode 0644
  owner "root"
  group "root"
end

bash "reload upstart configuration" do
  user 'root'
  code 'initctl reload-configuration'
end
